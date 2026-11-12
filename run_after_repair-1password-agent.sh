#!/usr/bin/env bash

# Runs on every apply and is idempotent: makes ~/.1password/agent.sock the one
# working 1Password SSH agent path on macOS, native Linux and WSL, then checks
# it. Problems are reported, never fatal, so an apply is not aborted.

SOCK="$HOME/.1password/agent.sock"
MAC_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
RELAY_UNIT="$HOME/.config/systemd/user/npiperelay.service"
OS="$(uname -s)"

warn() { echo "⚠️  $*" >&2; }
fail() { echo "❌ $*" >&2; }
is_wsl() { [ -n "${WSL_DISTRO_NAME:-}" ]; }

# The op CLI alone doesn't mean an agent is expected (servers use it for secrets),
# so look for the desktop app, its config, or an already-present socket.
has_onepassword() {
	if is_wsl; then
		[ -f "$RELAY_UNIT" ] && return 0
	fi
	command -v 1password >/dev/null 2>&1 && return 0
	[ -d /Applications/1Password.app ] && return 0
	[ -d "$HOME/.config/1Password" ] && return 0
	[ -S "$SOCK" ] && return 0
	return 1
}

# macOS: the real socket lives in a Group Container; link the canonical path to it
repair_macos_symlink() {
	mkdir -p "$HOME/.1password"
	if [ -L "$SOCK" ]; then
		[ "$(readlink "$SOCK")" = "$MAC_SOCK" ] || ln -sfn "$MAC_SOCK" "$SOCK"
	elif [ -S "$SOCK" ]; then
		:  # a real socket (1Password created it itself); nothing to repair
	elif [ -e "$SOCK" ]; then
		warn "$SOCK exists and is not a symlink; leaving it alone. Remove it to let this script link it to 1Password's socket."
	else
		ln -s "$MAC_SOCK" "$SOCK"
	fi
}

# WSL: build npiperelay.exe once, then keep the relay service pointed at $SOCK
repair_wsl_relay() {
	# Homebrew provides socat and mise; load it only if they aren't already reachable
	if ! command -v mise >/dev/null 2>&1 && [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
		eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
	fi

	local dep
	for dep in socat mise git wslpath cmd.exe; do
		if ! command -v "$dep" >/dev/null 2>&1; then
			fail "$dep not found. Skipping WSL 1Password agent relay setup."
			return
		fi
	done

	local win_profile npiperelay_exe npiperelay_link
	win_profile="$(cd /mnt/c 2>/dev/null; cmd.exe /C "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')"
	if [ -z "$win_profile" ]; then
		fail "Could not resolve the Windows user profile via cmd.exe. Skipping WSL 1Password agent relay setup."
		return
	fi

	npiperelay_exe="$(wslpath "$win_profile")/.npiperelay/npiperelay.exe"
	npiperelay_link="$HOME/.local/bin/npiperelay.exe"

	if [ ! -f "$npiperelay_exe" ]; then
		echo "🛠️ Building npiperelay.exe..."
		local build_dir
		build_dir="$(mktemp -d)"
		git clone --quiet --depth 1 https://github.com/jstarks/npiperelay.git "$build_dir"
		mkdir -p "$(dirname "$npiperelay_exe")"
		(
			cd "$build_dir"
			export GOPATH="${XDG_DATA_HOME:-$HOME/.local/share}/go"
			export GOCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/go-build"
			GOOS=windows GOARCH=amd64 mise exec go@latest -- go build -o "$npiperelay_exe" .
		) || { fail "Building npiperelay.exe failed."; rm -rf "$build_dir"; return; }
		rm -rf "$build_dir"
		echo "✅️ npiperelay.exe built!"
	fi

	mkdir -p "$(dirname "$npiperelay_link")"
	ln -sf "$npiperelay_exe" "$npiperelay_link"

	if ! systemctl --user show-environment >/dev/null 2>&1; then
		fail "systemd isn't running for your user in this WSL distro, so the 1Password agent relay can't be managed. Set \"systemd=true\" under [boot] in /etc/wsl.conf, then run \"wsl --shutdown\" from Windows and reopen WSL."
		return
	fi

	systemctl --user daemon-reload
	systemctl --user enable --now npiperelay.service

	# Restart when the socket is missing, or exists but nothing healthy is behind it
	local dead=0
	if [ -S "$SOCK" ]; then
		SSH_AUTH_SOCK="$SOCK" ssh-add -l >/dev/null 2>&1
		[ $? -eq 2 ] && dead=1
	fi
	if [ ! -S "$SOCK" ] || [ "$dead" -eq 1 ]; then
		systemctl --user restart npiperelay.service
		local i
		for i in 1 2 3 4 5 6; do
			[ -S "$SOCK" ] && break
			sleep 0.5
		done
	fi
}

verify_agent() {
	if ! command -v ssh-add >/dev/null 2>&1; then
		warn "ssh-add not found; can't verify the 1Password SSH agent."
		return
	fi
	SSH_AUTH_SOCK="$SOCK" ssh-add -l >/dev/null 2>&1
	case $? in
		0) ;;
		1) warn "1Password SSH agent is reachable but has no keys. Ensure 1Password is unlocked and your SSH keys are enabled for the agent." ;;
		*) fail "1Password SSH agent is unreachable at $SOCK. Ensure 1Password is running with Settings → Developer → \"Use the SSH agent\" enabled." ;;
	esac
}

has_onepassword || exit 0

if [ "$OS" = "Darwin" ]; then
	repair_macos_symlink
elif is_wsl; then
	repair_wsl_relay
fi

verify_agent
exit 0
