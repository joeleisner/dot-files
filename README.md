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

## Extending

This repo only tracks what the harness itself needs. Add your own config by dropping files into:

- `~/.config/bash/bashrc.d/`: sourced in order by name, so use a numeric prefix (`50-work`)
- `~/.ssh/config.d/`: pulled in by `Include config.d/*` at the top of `~/.ssh/config`

**SSH ordering matters.** ssh uses the first value it finds for each option, and the harness's `99-defaults.conf` (the `Host *` defaults) is last. Name your own files with a prefix **lower than 99** (e.g. `50-work.conf`). A file like `work.conf` sorts after `99-` and loses to the defaults.

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
