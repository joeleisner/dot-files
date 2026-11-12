# Dotfiles harness simplification — design

Date: 2026-11-12

## Intent

This chezmoi repo is a **harness around how Joel uses a terminal day-to-day**, and is being turned into something closer to a reusable template. It should track only what is fundamental to that harness. Anything specific to one machine, one employer, or one hobby lives outside it and plugs in through documented extension points.

Three changes serve that:

1. Remove workstation-specific tooling (iPod, KDE, at-home scripts).
2. Rebuild SSH config around the industry-standard `~/.ssh/config.d/` convention, with better defaults.
3. Make the 1Password SSH agent socket consistent and self-repairing on every platform.

1Password remains a first-class, intentional dependency, but only for two things: the SSH agent (accessing servers) and git commit signing.

## Goals

- Repo contains no personal host entries, no workstation-only scripts, no 1Password-fetched SSH config.
- `~/.ssh/config.d/` and `~/.config/bash/bashrc.d/` are the documented extension points, so extra config can be dropped in without touching the repo.
- Same SSH agent socket path on macOS, native Linux and WSL, with no OS conditionals in ssh config.
- `chezmoi apply` on any machine (workstation, work laptop, fresh install) detects and repairs a broken agent setup, and says specifically what is wrong if it cannot.
- Safer SSH defaults, with no agent forwarding unless a host opts in.
- git-over-ssh no longer collides with SSH connection multiplexing.

## Non-goals

- No XDG relocation of 1Password's socket. 1Password owns `~/.1password/agent.sock`; revisit if they add XDG support.
- Not tracking or templating the user's real `Host` entries, work servers, or per-employer config.
- Not publishing the iPod/KDE/at-home scripts. That is a separate future decision (own GitHub projects, or local-only).
- No new abstraction layers, plugin systems, or config frameworks. Keep it small.

## Anti-goals (would be a failure even if it technically works)

- Any `ForwardAgent yes` in tracked config applying to all hosts.
- Any dependency on 1Password for the SSH *config text* (only the agent and signing key).
- An apply that silently leaves the agent broken.
- Deleting or overwriting the user's existing rendered scripts in `~/.local/bin`.

## Current state (as of commit e966075)

- `.chezmoi.toml.tmpl` prompts for `has_ipod`, `is_kde`, `at_home` plus `ipod_*`, `peripheral_switch_device`, `monitor_bus_*`, and `ssh_conf_secret` (1Password URI).
- Nine templated scripts in `dot_local/bin/` are gated on those flags: `icover`, `icoverr`, `iname`, `isync`, `podify` (ipod); `switch-activity`, `switch-desktop` (kde); `switch-monitors`, `switch-peripherals` (at_home).
- `private_dot_ssh/private_config.tmpl` pulls the whole config from 1Password via `onepasswordRead .ssh_conf`, then appends a `Host *` block with `IdentityAgent SSH_AUTH_SOCK`, `ForwardAgent yes`, and `ControlPath ~/.ssh/control/%r@%h:%p`. `private_dot_ssh/private_control/.keep` creates the control dir.
- `SSH_AUTH_SOCK` is set inconsistently: `bashrc.d/90-linux` chooses `~/.ssh/agent.sock` (WSL) or `~/.1password/agent.sock` (else); `zsh/zshrc.d/90-zsh` hardcodes `~/.ssh/agent.sock` unconditionally.
- WSL relay: `dot_config/systemd/user/npiperelay.service` listens on `~/.ssh/agent.sock`; `run_onchange_after_setup-wsl-op-agent.tmpl` builds `npiperelay.exe` and enables the service, but only re-runs when the service file changes (cannot repair).
- `bashrc.d/95-ssh` warns if `ssh-add -l` fails.
- Git config (`dot_config/git/executable_config.tmpl`) already handles `op-ssh-sign` vs `op-ssh-sign.exe` for signing.
- The zsh config symlinks most of the bashrc.d files (`symlink_*`).

## Design

### 1. Removals

- Delete the nine scripts listed above from `dot_local/bin/`.
- In `.chezmoi.toml.tmpl` remove the prompts and `[data]` keys: `has_ipod`, `is_kde`, `at_home`, `ipod_music_src`, `ipod_podcast_src`, `ipod_mount_path`, `peripheral_switch_device`, `monitor_bus_1`, `monitor_bus_2`, and `ssh_conf_secret`/`ssh_conf`.
- Remove the corresponding README feature-table rows and any README text about 1Password-sourced SSH config.
- **Do not** add `.chezmoiremove` entries. The scripts already exist as unmanaged, rendered files in `~/.local/bin` on the workstation and must stay. They remain in git history.
- Existing `~/.config/chezmoi/chezmoi.toml` files keep stale keys; harmless, no migration.

### 2. SSH config

`~/.ssh/config` (chezmoi-managed, private) contains essentially only:

```
Include config.d/*
```

Rules:
- `Include` first (ssh uses first-obtained value per option, so ordering matters).
- `~/.ssh/config.d/` is created by chezmoi (private, 0700) and is the extension point. Chezmoi must not delete unmanaged files there.
- Tracked files, named to sort by the same numeric-prefix convention as `bashrc.d`:
  - `99-defaults.conf`: a `Host *` block with (and, after it, `Match exec "test -S %d/.1password/agent.sock"` + `IdentityAgent %d/.1password/agent.sock`, so it is a default users can override earlier and is ignored on machines without 1Password; changed after final review):
    - `ControlMaster auto`
    - `ControlPath ~/.ssh/control/%C` (hash token; avoids the ~104-char unix-socket limit)
    - `ControlPersist 10m`
    - `ServerAliveInterval 60`, `ServerAliveCountMax 3`
    - `AddKeysToAgent yes`
    - `HashKnownHosts yes`
    - **No `ForwardAgent`.**
- Keep `~/.ssh/control/` (via the existing `private_control/.keep`); the name is conventional enough.
- Hosts that need agent forwarding opt in per-host in the user's own config (documented in the README: use `ProxyJump` for bastions; `ForwardAgent yes` only on trusted hosts where git/ssh is run from the host).
- Stowed or hand-placed config files must be mode 0600/0644 (ssh rejects group/world-writable); the README should note this.

### 3. Git and multiplexing

In `dot_config/git/executable_config.tmpl` add:

```
[core]
	sshCommand = ssh -o ControlMaster=no -o ControlPath=none
```

This disables multiplexing for all git-over-ssh regardless of hostname (fixes the Bitbucket "another connection already open / ControlSocket already exists" notice) while interactive `ssh` keeps multiplexing.

### 4. 1Password agent socket

Canonical path on every platform: **`~/.1password/agent.sock`**.

- **Linux (native):** 1Password creates it. Nothing to do beyond verification.
- **macOS:** chezmoi ensures `~/.1password/agent.sock` is a symlink to 1Password's real socket under `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` (the setup 1Password's docs suggest). *(Builder: verify the exact path against current 1Password docs.)*
- **WSL:** `npiperelay.service` listens directly on `~/.1password/agent.sock` (`mkdir -p` the directory in `ExecStartPre`; keep the `rm -f` of a stale socket). The `~/.ssh/agent.sock` path is retired.
- `SSH_AUTH_SOCK=$HOME/.1password/agent.sock` is set in **one** shared env location (the existing `00-env`), replacing both the `90-linux` logic and the hardcoded `90-zsh` line. zsh already symlinks `00-env`, so it follows automatically. **Guarded** (my call): skip when `SSH_CONNECTION` is set (remote session, where sshd may have forwarded an agent) and only export when the socket exists.

**Self-healing:** replace `run_onchange_after_setup-wsl-op-agent.tmpl` with a `run_after_` script (runs every apply, idempotent), which per OS:
- macOS/Linux: ensure canonical path is correct (macOS symlink); 
- WSL: keep the existing npiperelay.exe build/link logic; ensure the service is enabled and active, restarting it if the socket is missing or dead;
- All: verify with `SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l` and print a specific diagnosis on failure (socket missing; agent reachable but no keys / 1Password locked; ssh-add not installed), without failing the whole apply.
- Still skip quietly when `op` is not installed, consistent with `run_after_check-onepassword.tmpl`. The existing service-file hash trick (`include ... | sha256sum`) is no longer needed for triggering, but the service file must still be installed/updated by chezmoi as it is today.

`bashrc.d/95-ssh` (shell-start warning) stays.

### 5. Tooling and documentation

- Add `stow` to `.chezmoitemplates/Brewfile-packages`.
- README additions:
  - The extension points (`bashrc.d`, `config.d`) and the numeric-prefix ordering convention for both.
  - Recommended way to link external projects (work servers repo, iPod project) into those directories: GNU Stow with `--no-folding` (so Stow links files rather than replacing the directory, which would collide with harness-owned files).
  - SSH guidance: per-host `ForwardAgent`, `ProxyJump`, file permissions.
  - Update the prompts/feature list and 1Password section to match removals.

### 6. Edge cases (added after builder review; my calls unless noted)

- **No backup or migration of the existing `~/.ssh/config`.** The user's host entries originate in 1Password and are already saved elsewhere, so the first apply may overwrite the rendered file. This is the user's decision; treat the setup as a fresh start.
- **`IdentitiesOnly` is not a global default.** With the 1Password agent it only offers keys named by `IdentityFile`, which would break hosts that lack one. The README documents it as a per-host opt-in (with `IdentityFile` pointing at the public key), for when "too many authentication failures" appears. Git hosts need no entry.
- **Ordering rule is prominent in the README:** external `config.d` files must be named with a prefix below `99` (e.g. `50-work.conf`), because `99-defaults.conf` is last and first value wins.
- **Gating of the repair script:** do not gate on the `op` CLI alone. Repair/verify runs when 1Password is detected (macOS app present, `op`/`op.exe` found, or the WSL relay already installed) and skips quietly otherwise (e.g. headless servers). Detection details are the builder's.
- **Non-destructive repair:** the script only creates or replaces symlinks or absent paths. If `~/.1password/agent.sock` is a regular file or directory it warns and leaves it alone. A missing socket on Linux with 1Password closed is reported, not "fixed".
- **WSL upgrade path:** after installing the updated unit, run `daemon-reload` and restart the service so existing installs move to the new path, and remove the stale `~/.ssh/agent.sock`.
- **Message wording:** update `run_after_check-onepassword.tmpl`, which still mentions "1Password-sourced SSH config".

## Constraints

- Chezmoi conventions: `private_` for `.ssh`, templates only where needed, existing prompt/`promptStringOnce` pattern retained for remaining prompts (`git_name`, `git_email`, `git_signing_key_uri`).
- Must work on macOS (work laptop), Fedora Atomic-style native Linux (workstation, Homebrew at `/home/linuxbrew`), and WSL.
- The user wants to run `chezmoi apply` on the workstation soon, after not applying for a while. The change must be safe there (see anti-goals).
- Avoid over-engineering; prefer fewer files and no new tools beyond `stow`.

## Decided by the user

- Remove the three feature modules and their scripts from the repo; keep the rendered copies locally.
- Drop `ForwardAgent` from global config; per-host only.
- Use `%C` for ControlPath; keep `~/.ssh/control`.
- Keep `~/.1password/agent.sock` as canonical path; no XDG relocation.
- Use a `config.d` directory convention instead of pulling config from 1Password; track nothing that is not fundamental.
- 1Password-centric, but only for the SSH agent and git signing.
- Install Stow via Homebrew; Stow is the suggested linking convention.
- Self-healing agent setup on every apply.

## My calls (flagged, not user-decided)

- Name `config.d` (OpenSSH convention) rather than `sshrc.d` (which collides with the unrelated `~/.ssh/rc` / sshrc tool).
- The exact keepalive, `IdentitiesOnly`, `AddKeysToAgent`, `HashKnownHosts` values in the defaults file.
- Fixing git multiplexing via `core.sshCommand` rather than per-host `ControlMaster no`.
- macOS symlink approach for the canonical socket path.
- Replacing the `run_onchange` WSL script with a `run_after` script, and what the diagnosis messages say.

## Left to the builder

- Exact script structure and wording of diagnostics.
- How to express the macOS symlink (chezmoi `symlink_` template vs. in the run_after script), as long as apply repairs it.
- Whether `config.d` files are plain files or templates (plain preferred).
- Verifying macOS socket path and that `IdentityAgent` with `~` expansion works as intended.
- Testing approach (e.g. `chezmoi apply --dry-run`, `chezmoi execute-template`, `ssh -G <host>` to inspect effective config).
