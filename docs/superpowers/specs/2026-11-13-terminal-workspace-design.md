# Terminal workspace (tmux + Helix + `proj`) — design

Date: 2026-11-13

## Intent

Joel is moving toward doing most work from the terminal, with the Claude Code CLI as the main coding interface. Three frictions stand in the way, and none of them is AI-specific:

1. **Opening an editor takes a beat**, and he rarely edits by hand anymore, so it isn't worth launching.
2. **Vim is avoided** because maintaining its plugins and config language was painful, not because of vim itself.
3. **He can't easily jump back into conversations with agents** about the projects he's working on.

This adds a small baseline to the harness that addresses all three: a multiplexer (tmux), a zero-fuss editor (Helix), and one wrapper script (`proj`) that gets him into a project. The result will naturally be an AI-oriented workflow, but the pieces must make sense without any AI tool.

The key insight: (1) and (3) are the same problem. If a project has a persistent session with an editor and an agent already running, nothing needs launching or re-finding. That is what tmux provides.

## Goals

- `tmux` and `helix` are installed through `.chezmoitemplates/Brewfile-packages`, so a machine without them gets them on `chezmoi apply`.
- `fzf` is added to the same Brewfile. zoxide's interactive picker (`zi`) requires it, and the harness already ships zoxide, so `zi` currently fails on a fresh machine. `proj` doesn't depend on it.
- A short, readable tmux config: sensible defaults, no plugins.
- A tiny Helix config: Helix works well out of the box, so the file only records a handful of preferences.
- `proj`, a script in `dot_local/bin/`, with two modes through one command:
  - **Light (default):** go to a project and start the agent there, resuming its last conversation for that directory. Nothing stays running afterwards.
  - **Session (opt-in flag):** create or reattach a long-lived tmux session for the project, containing an editor, an agent and a shell.
- Keybind rustiness is a design input: keep tmux's default prefix, and ship a short cheat sheet of only the bindings this config actually adds or relies on.
- Everything stays XDG-compliant and works on macOS, native Linux and WSL, under bash and zsh.

## Non-goals

- No tmux plugin manager (TPM) and no tmux or Helix plugins.
- No session auto-restore across reboots (e.g. tmux-resurrect). Sessions survive detaching, not rebooting.
- No installing language servers or Helix grammars. `hx --health` tells him what is missing; he adds what he needs.
- No custom theme, statusline framework or terminal emulator config.
- No zellij support, and no abstraction over multiplexers.
- No AI-tool-specific logic in the tmux or Helix configs. The agent is just a command in a window.
- No bundled project registry. Projects are resolved with zoxide, which is already in the harness.

## Anti-goals (a failure even if it technically works)

- tmux auto-starting in every shell, or on every ssh login. Sessions begin only when asked.
- Remapping tmux's prefix or core bindings so far that vanilla tmux on a server feels foreign. The same muscle memory should work locally and over ssh.
- A config that becomes the thing he has to maintain. If the tmux config passes roughly 40 lines or the Helix config roughly 15, something went wrong.
- `proj` ever killing a session, closing a window or discarding someone's running work.
- `claude` hardcoded in a way that can't be changed (the agent command must be overridable).

## Constraints

- Repo conventions: XDG paths, minimal, shell-impartial, extension through `bashrc.d`. It is also being shaped into a reusable template, so personal choices need to be overridable rather than baked in.
- `docs/` is already excluded from deployment through `.chezmoiignore`. The new config files must not be.
- tmux 3.8 is installed locally; tmux 3.1+ reads `~/.config/tmux/tmux.conf` natively, so no XDG workaround is needed. Helix reads `~/.config/helix/config.toml` natively.
- The existing zoxide setup is under `ZOXIDE_CMD` control. `proj` should call `zoxide query` directly, not depend on the `z` function.
- `proj` is a bash script (like `llf` and `path`), so it works regardless of the interactive shell. It cannot change the calling shell's directory, which is fine: both of its modes launch something in the target directory instead.

## Approaches considered

- **A. tmux plus a small project script — chosen.** tmux is already on this machine and is the multiplexer found on the servers he ssh's into, so the muscle memory carries over. Its default prefix (`Ctrl-b`) doesn't collide with Helix. Trade-off: tmux's defaults are poor, so a short config is needed.
- **B. Zellij plus layout files — rejected.** Friendlier defaults and declarative layouts, but its default keybindings clash with Helix (needing a locked-by-default setup) and it is rarely installed on remote servers.
- **C. Scripts only, no multiplexer — rejected.** Least to maintain, but it fails the goal of making persistent sessions possible, and adding a multiplexer later would mean redesigning the script.

Within A, the choice of **light by default, session opt-in** reflects that Joel doesn't currently work with long-lived sessions but wants them available.

## Decided (as Joel decided them)

- tmux is the multiplexer, defined in the Brewfile so it's installed when missing.
- Helix is the editor.
- A basic config for tmux is wanted; the maintenance pain was specifically vim's plugins and config language, not configs in general.
- He is rusty on tmux keybinds, so discoverability matters.
- Heavy (persistent) sessions should be possible but are not his current default.

## My calls (flagged for review)

- **Script name `proj`.** Short, unused. Easy to rename.
- **Light is the default and the session mode is a flag** (e.g. `proj -s name`). The reasoning is the "possible, not default" he described.
- **Project resolution:** an argument is resolved with `zoxide query`, falling back to treating it as a path; no argument means the current directory. The session name is the sanitized directory basename.
- **Agent command is a variable**, `PROJ_AGENT`, defaulting to `claude --continue`, documented as overridable in `bashrc.d`. Light mode runs it in the project directory.
- **Session layout:** three windows named `edit` (running `hx`), `agent` (running the agent command) and `shell`. Reattaching uses `attach`, or `switch-client` when already inside tmux, and never recreates an existing session.
- **`EDITOR` and `VISUAL` default to `hx`** in `bashrc.d/00-env`, guarded so a value already set (or set by his own earlier `bashrc.d` file) wins. This makes git commit messages and similar open Helix.
- **tmux config contents** (roughly): mouse on, windows and panes numbered from 1, a low `escape-time` (Helix needs it), focus events on, true-colour support, a larger scrollback, splits on `|` and `-` that open in the current directory, new windows in the current directory, a reload binding, and a minimal status line that shows the session name.
- **Helix config contents:** a theme and a very small set of editor preferences. Anything else stays at Helix's defaults.
- **Cheat sheet** lives in the README, covering only the bindings above plus `?` (tmux's built-in key list) and Helix's `:tutor`.

## Left to the builder

- Exact tmux option names and values, within the size limits above.
- `proj`'s flag spelling and help text, and handling of two directories with the same basename.
- Whether the session-mode flag also supports a bare `proj -s` for the current directory.
- Which Helix theme and preferences to pick.
- README wording and placement of the new section.
- Verification approach: shellcheck for `proj`, `tmux -f ... start-server \; source-file` to confirm the config parses, `hx --health`, and `chezmoi apply --dry-run`.
