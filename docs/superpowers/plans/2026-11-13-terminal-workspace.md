# Terminal Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tmux, Helix, fzf and a `proj` script to the dotfiles harness so a project can be entered in one command, either as a light "resume the agent here" or a persistent tmux session.

**Architecture:** Three packages go into the existing Brewfile. Two small XDG config files (tmux, Helix) are tracked as plain chezmoi files. One bash script, `proj`, lives in `dot_local/bin/` and either launches the agent in a project directory (default) or creates/reattaches a named tmux session (`-s`). No plugins, no auto-start.

**Tech Stack:** bash, tmux 3.8 (reads `~/.config/tmux/tmux.conf`), Helix (`hx`), zoxide (already shipped), chezmoi, Homebrew.

**Spec:** `docs/superpowers/specs/2026-11-13-terminal-workspace-design.md`

## Global Constraints

- tmux config stays under about 40 lines; Helix config under about 15.
- No tmux plugin manager, no tmux or Helix plugins.
- tmux's default prefix `Ctrl-b` is kept; no remapping of core bindings.
- XDG paths: `~/.config/tmux/tmux.conf`, `~/.config/helix/config.toml`, script at `~/.local/bin/proj`.
- Packages go in `.chezmoitemplates/Brewfile-packages` (not `Brewfile-overrides`): `tmux`, `helix`, `fzf`.
- `proj` is a bash script that works whatever the interactive shell is. It uses `zoxide query` directly, never the `z` function.
- Agent command comes from `PROJ_AGENT`, defaulting to `claude --continue`. Nothing in the tmux or Helix configs names an AI tool.
- Session windows are named exactly `edit` (runs `hx`), `agent` (runs the agent command) and `shell`.
- `EDITOR` and `VISUAL` default to `hx` only when not already set.
- tmux never auto-starts from shell config; `proj` never kills a session, closes a window or discards running work.
- Works on macOS, native Linux and WSL, under bash and zsh. `docs/` stays excluded from deployment; the new config files must not be.

## Review Focus

Spec-implied conditions no spec line spells out, most likely first. Each has a test in the task that owns the code.

1. `proj nonexistent` fails with a clear message and non-zero exit, and creates no session. (Task 4)
2. Directory names containing `.`, `:` or spaces (e.g. `my.app`, `a b`) still produce a working session; tmux forbids `.` and `:` in session names. (Task 4)
3. Running `proj -s` twice for the same project reattaches or reuses the session and never duplicates windows. (Task 4)
4. When the agent exits, its window drops to a shell instead of vanishing, so the session isn't lost. (Task 4)
5. Two different directories sharing a basename (`~/a/app`, `~/b/app`) don't land in the same session. (Task 4)

---

### Task 1: Packages and editor default

**Files:**
- Modify: `.chezmoitemplates/Brewfile-packages`
- Modify: `dot_config/bash/bashrc.d/00-env`

**Interfaces:**
- Produces: `tmux`, `hx` and `fzf` installed by `brew bundle`; `EDITOR`/`VISUAL` exported as `hx` unless already set.

- [ ] **Step 1: Write the failing check**

Run from the repo root:

```bash
for v in EDITOR VISUAL; do
  [ "$(env -i HOME="$(mktemp -d)" bash -c "source dot_config/bash/bashrc.d/00-env; echo \${$v}")" = hx ] || echo "FAIL default $v"
done
[ "$(env -i HOME="$(mktemp -d)" EDITOR=vim bash -c 'source dot_config/bash/bashrc.d/00-env; echo $EDITOR')" = vim ] || echo "FAIL preset EDITOR overridden"
for p in tmux helix fzf; do grep -q "^brew \"$p\"" .chezmoitemplates/Brewfile-packages || echo "FAIL missing $p"; done
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `FAIL default EDITOR`, `FAIL default VISUAL`, and three `FAIL missing` lines. The preset check passes trivially.

- [ ] **Step 3: Implement**

In `Brewfile-packages`, add `brew "fzf"` under the "Core Prompt & Navigation" group (it backs zoxide's `zi`) and a new "Terminal Workspace" group holding `brew "tmux"` and `brew "helix"`. In `00-env`, add a short commented block exporting `EDITOR` and `VISUAL` as `"${EDITOR:-hx}"` and `"${VISUAL:-hx}"` respectively.

- [ ] **Step 4: Run the check to verify it passes**

Re-run Step 1. Expected: no output. Then `HOMEBREW_BUNDLE_NO_LOCK=1 brew bundle --file=.chezmoitemplates/Brewfile-packages` and confirm `command -v tmux hx fzf` finds all three.

- [ ] **Step 5: Commit**

```bash
git add .chezmoitemplates/Brewfile-packages dot_config/bash/bashrc.d/00-env
git commit -m "feat: Add tmux, helix and fzf packages and default EDITOR to hx"
```

### Task 2: tmux config

**Files:**
- Create: `dot_config/tmux/tmux.conf`

**Interfaces:**
- Produces: bindings `prefix |` (split left/right), `prefix -` (split top/bottom), `prefix c` (new window), each in `#{pane_current_path}`, and `prefix r` (reload with a "Reloaded" message). Used by the README cheat sheet in Task 5.

- [ ] **Step 1: Write the failing check**

```bash
export TMUX_TMPDIR=$(mktemp -d)
tmux -f /dev/null new-session -d -s t
tmux source-file dot_config/tmux/tmux.conf && echo PARSE_OK
[ "$(tmux show -gv mouse)" = on ] || echo "FAIL mouse"
[ "$(tmux show -gv escape-time)" = 10 ] || echo "FAIL escape-time"
[ "$(tmux show -gv base-index)" = 1 ] || echo "FAIL base-index"
[ "$(tmux show -gv prefix)" = C-b ] || echo "FAIL prefix"
[ "$(tmux list-keys -T prefix | grep -c pane_current_path)" -ge 3 ] || echo "FAIL path-preserving binds"
tmux show -s terminal-features | grep -q RGB || echo "FAIL truecolor"
[ "$(wc -l < dot_config/tmux/tmux.conf)" -le 40 ] || echo "FAIL too long"
tmux kill-server
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `source-file` errors (file missing), so no `PARSE_OK`.

- [ ] **Step 3: Implement `dot_config/tmux/tmux.conf`**

Set the options the spec lists: mouse on, windows and panes numbered from 1 (with `renumber-windows on`), `escape-time 10`, `focus-events on`, true-colour via `default-terminal "tmux-256color"` plus `terminal-features ",*:RGB"`, `history-limit 50000`, a minimal status line showing the session name. Add the four bindings from Interfaces. Comment each group in one line. Do not rebind the prefix.

- [ ] **Step 4: Run the check to verify it passes**

Re-run Step 1. Expected: `PARSE_OK` and nothing else.

- [ ] **Step 5: Commit**

```bash
git add dot_config/tmux/tmux.conf
git commit -m "feat: Add basic tmux config"
```

### Task 3: Helix config

**Files:**
- Create: `dot_config/helix/config.toml`

- [ ] **Step 1: Write the failing check**

```bash
f=dot_config/helix/config.toml
[ -f $f ] || echo "FAIL missing file"
hx -c $f --health 2>&1 | grep -qi 'error' && echo "FAIL config errors"
[ "$(wc -l < $f)" -le 15 ] || echo "FAIL too long"
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `FAIL missing file`.

- [ ] **Step 3: Implement `dot_config/helix/config.toml`**

A `theme` key and an `[editor]` table with at most a few preferences (e.g. `line-number = "relative"`, `cursorline = true`, `bufferline = "multiple"`). Leave everything else at Helix defaults. No keymap overrides.

- [ ] **Step 4: Run the check to verify it passes**

Run `hx -c dot_config/helix/config.toml --health 2>&1 | head -5`. Expected: shows the config file path with no error lines.

- [ ] **Step 5: Commit**

```bash
git add dot_config/helix/config.toml
git commit -m "feat: Add minimal Helix config"
```

### Task 4: `proj` script

**Files:**
- Create: `dot_local/bin/executable_proj`

**Interfaces:**
- Consumes: `tmux`, `hx`, `zoxide` on `PATH`; `PROJ_AGENT` (default `claude --continue`).
- Produces the command `proj [-s] [-d] [-h] [project]`:
  - `project` is an existing directory path, else resolved with `zoxide query -- "$project"`, else the current directory when omitted.
  - No flags (light): `cd` to the directory, then `exec` the `PROJ_AGENT` command.
  - `-s`: create the session if it doesn't exist (windows `edit` → `hx`, `agent` → agent command that falls back to a shell when it exits, `shell`), select `edit`, then attach (`switch-client` when `$TMUX` is set).
  - `-d` (with `-s`): create but don't attach.
  - `-h`: usage, exit 0. Unresolvable project: message on stderr, exit 1, nothing created.
  - Session name: directory basename with `.` and `:` replaced by `_`. If a session of that name exists whose `#{session_path}` is a different directory, append `-` and the first 4 digits of `printf %s "$dir" | cksum`. Look sessions up with exact match (`-t "=$name"`).

The tests use a scratch socket via `TMUX_TMPDIR` and `-d`, so they need no terminal. Setup shared by the steps below:

```bash
export TMUX_TMPDIR=$(mktemp -d); T=$(mktemp -d)
mkdir -p "$T/p1" "$T/my.app" "$T/a b" "$T/x/app" "$T/y/app"
export PROJ_AGENT='echo agent-ran-in $PWD'
P=dot_local/bin/executable_proj
```

- [ ] **Step 1: Write the failing tests**

```bash
# light mode
[ "$(bash $P "$T/p1")" = "agent-ran-in $T/p1" ] || echo "FAIL light"
# unknown project: error, exit 1, no tmux server started
bash $P -s -d nonexistent-zzz 2>err; [ $? -eq 1 ] && [ -s err ] || echo "FAIL unknown project"
tmux ls 2>/dev/null && echo "FAIL session leaked"
# session layout
bash $P -s -d "$T/p1"
[ "$(tmux list-windows -t =p1 -F '#W' | paste -sd,)" = edit,agent,shell ] || echo "FAIL layout"
# idempotent
bash $P -s -d "$T/p1"; [ "$(tmux list-windows -t =p1 | wc -l)" = 3 ] || echo "FAIL duplicated windows"
# awkward names
bash $P -s -d "$T/my.app"; tmux has-session -t =my_app || echo "FAIL dot name"
bash $P -s -d "$T/a b";    tmux has-session -t "=a b" || echo "FAIL space name"
# same basename, different dirs
bash $P -s -d "$T/x/app"; bash $P -s -d "$T/y/app"
[ "$(tmux ls -F '#S' | grep -c '^app')" = 2 ] || echo "FAIL basename collision"
# agent exit leaves the window alive
sleep 1; tmux list-windows -t =p1 -F '#W' | grep -q agent || echo "FAIL agent window vanished"
tmux kill-server
```

- [ ] **Step 2: Run them to verify they fail**

Expected: every check fails (script missing).

- [ ] **Step 3: Implement `proj`**

Bash with `set -euo pipefail`. Split into small functions: `usage`, `resolve_dir`, `session_name`, `ensure_session`, `go_to_session`. Verify `zoxide` exists only when it's actually needed (path arguments shouldn't need it). The agent window command is `"$PROJ_AGENT; exec \"\${SHELL:-bash}\""` so the window survives the agent exiting. Pass directories to tmux with `-c`, never by interpolating into a shell string.

- [ ] **Step 4: Run the tests to verify they pass**

Re-run Step 1. Expected: no `FAIL` lines. Also run `shellcheck dot_local/bin/executable_proj` (install via brew if absent); expected clean. Finally, from inside a real tmux window run `bash $P -s "$T/p1"` and confirm the client switches sessions instead of nesting.

- [ ] **Step 5: Commit**

```bash
git add dot_local/bin/executable_proj
git commit -m "feat: Add proj script for project agent and tmux sessions"
```

### Task 5: README and apply check

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the failing check**

```bash
grep -q 'proj' README.md && grep -q 'PROJ_AGENT' README.md && grep -q 'tmux' README.md || echo "FAIL docs"
chezmoi managed --source . | grep -E '\.config/(tmux/tmux\.conf|helix/config\.toml)|\.local/bin/proj' | wc -l   # expect 3
chezmoi apply --dry-run --source . >/dev/null && echo APPLY_OK
```

- [ ] **Step 2: Run it to verify it fails**

Expected: `FAIL docs`.

- [ ] **Step 3: Implement the README changes**

Add a Features entry for the terminal workspace and mention fzf alongside zoxide's `zi`. Add a "Terminal workspace" section covering: what `proj` does in light vs `-s` mode (with `-d`), overriding `PROJ_AGENT` in `bashrc.d`, that sessions survive detaching but not reboots, and a cheat sheet limited to: `Ctrl-b d` (detach), `Ctrl-b |` / `-` (splits), `Ctrl-b c` (new window), `Ctrl-b 1`–`9` (switch window), `Ctrl-b r` (reload), `Ctrl-b ?` (full key list), plus `tmux ls` / `tmux attach` and Helix's `:tutor`.

- [ ] **Step 4: Run the check to verify it passes**

Expected: no `FAIL`, the managed count prints `3`, and `APPLY_OK` appears.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: Document terminal workspace and proj"
```
