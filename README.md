# Joel's Dot Files

My minimal, XDG-compliant, shell-impartial dot files + setup.

## Requirements

- `curl` and `git` for Homebrew install
- The 1Password desktop app + CLI tool (used only for the SSH agent and git commit signing)

## Features

1. Works w/ Bash or ZSH
2. Homebrew install
3. Development dependencies and overrides
4. Terminal bling
5. WSL support
6. 1Password-powered SSH agent and git commit signing
7. Sensible SSH defaults, with `config.d` and `bashrc.d` as extension points
8. Terminal workspace: tmux, Helix and a `proj` command (see below)

## Installation

During initial setup, the following will be ran:

1. Check for required dependencies
2. Install Homebrew
3. Install packages (for shell bling and web development)
4. Install overrides (for dev-critical packages)

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io/lb)" -- init --apply https://github.com/joeleisner/dot-files.git
```

*On WSL, a script to automatically set up the 1Password SSH agent relay will run. Git commit signing needs the 1Password CLI, so run `chezmoi apply` again afterwards to complete the setup.*

Every `chezmoi apply` also checks the 1Password SSH agent socket (`~/.1password/agent.sock`) and repairs it where it can (a symlink on macOS, the relay service on WSL), printing a specific warning if it can't.

## Terminal workspace

tmux, Helix (`hx`, the default `EDITOR`) and fzf (needed by zoxide's `zi`) are installed with the packages. `proj` ties them to your projects:

```sh
proj myapp       # cd to the project and run the agent there (resumes its last conversation, or starts one in a new project)
proj -s myapp    # create or reattach myapp's tmux session: edit (hx), agent, shell
proj -s -d myapp # same, but create it in the background without attaching
```

`myapp` is a directory or a name zoxide knows; leave it off to use the current directory. Sessions survive detaching, but not a reboot, and tmux never starts on its own.

### tmux cheat sheet

The prefix is the tmux default, `Ctrl-b`. Press it, release, then:

| Keys | Does |
| --- | --- |
| `Ctrl-b d` | Detach (the session keeps running) |
| `Ctrl-b \|` / `Ctrl-b -` | Split left/right / top/bottom |
| `Ctrl-b c` | New window |
| `Ctrl-b 1`–`9` | Go to window |
| `Ctrl-b r` | Reload `~/.config/tmux/tmux.conf` |
| `Ctrl-b ?` | List every key binding |

From a shell, `tmux ls` lists sessions and `tmux attach` reattaches. In Helix, `:tutor` is a built-in walkthrough.

## Extending

This repo only tracks what the harness itself needs. Add your own config by dropping files into:

- `~/.config/bash/bashrc.d/`: sourced in order by name, so use a numeric prefix (`50-work`)
- `~/.ssh/config.d/`: pulled in by `Include config.d/*` at the top of `~/.ssh/config`

**SSH ordering matters.** ssh uses the first value it finds for each option, and the harness's `99-defaults.conf` (the `Host *` defaults) is last. Name your own files with a prefix **lower than 99** (e.g. `50-work.conf`). A file like `work.conf` sorts after `99-` and loses to the defaults.

### Overrides

Set these in a `bashrc.d` file that sorts before the file that reads them (e.g. `01-env`):

- `ZOXIDE_CMD`: the command zoxide defines. Defaults to `z`; `ZOXIDE_CMD=cd` makes `cd` smart instead (and `z` is no longer defined). Note that `cd -P`/`cd -L` don't work with it, and a mistyped directory jumps to a frequent match instead of failing. In non-interactive shells (agent shells such as Claude Code, scripts that source your config) `cd` stays the plain builtin, so a typo fails instead of jumping and zoxide's prompt-hook check never warns.
- `EDITOR`/`VISUAL`: set to `hx` unconditionally, because distros pre-set `EDITOR` (Fedora sets nano) so a "keep any existing value" guard never fires. Export your own in a file that sorts after `00-env` (e.g. `50-editor`) to change them.
- `PROJ_AGENT`: (must be `export`ed, since `proj` is a separate process) the command `proj` runs as the agent, in light mode and in the session's `agent` window. Defaults to `claude --continue || claude` (resume the last conversation, or start a fresh one in a new project).

### Linking external projects

[GNU Stow](https://www.gnu.org/software/stow/) is installed with the Brewfile. Use `--no-folding` so Stow links individual files instead of replacing a directory with one symlink, which would collide with the files the harness owns:

```sh
stow --no-folding -d ~/projects -t ~ work-servers   # e.g. ~/projects/work-servers/.ssh/config.d/50-work.conf
```

ssh ignores config files that are group- or world-writable, so keep stowed ssh files at mode `0600` or `0644`.

### SSH tips

- `ForwardAgent` is off by default. Enable it per host, and only for trusted hosts where you run `git` or `ssh` from the host itself. For bastions, prefer `ProxyJump`.
- Git-over-ssh never uses connection multiplexing (`core.sshCommand` in the git config), so it won't fight with `ControlMaster` sockets.
- If you see "Too many authentication failures" with the 1Password agent, add `IdentitiesOnly yes` plus an `IdentityFile` pointing at the public key to that host. It isn't a global default because it would stop hosts without an `IdentityFile` from authenticating.
