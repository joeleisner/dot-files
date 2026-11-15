# `proj -s` on herdr — design

Date: 2026-11-15

## Intent

Joel tried herdr alongside tmux and finds it more comfortable day to day. He wants `proj -s` to build a herdr workspace instead of a tmux session, so getting into a project is still one command and he doesn't have to think about it.

## Goals

- `proj -s [project]` focuses the project's herdr workspace if one exists, otherwise creates one with three tabs in this order: `agent`, `edit`, `shell`. The agent tab is focused.
  - agent: `$PROJ_AGENT` (default `claude --continue || claude`, so the last conversation resumes)
  - edit: `hx`
  - shell: `mise tasks` first when the project has a `mise.toml`/`.mise.toml`, otherwise a plain shell
- `-d` creates the workspace without focusing it.
- Workspace label is the directory's basename. If a workspace with that label already belongs to a different directory, disambiguate (as the tmux version did).
- Outside herdr, `proj -s` attaches by launching `herdr` after creating the workspace.
- `proj` without `-s` is unchanged. `PROJ_AGENT` stays overridable.

## Non-goals / anti-goals

- No tmux fallback: `-s` requires herdr.
- `tmux.conf`, the Brewfile's tmux entry and the README tmux cheat sheet are left alone; removing tmux is a later decision.
- `proj` never closes a workspace, tab or pane, or discards running work.

## Constraints

- Uses only herdr's CLI (`workspace`, `tab`, `pane`), which returns JSON; IDs come from those responses, not guessed.
- Commands run in a real shell in each tab, so the shell survives the agent or editor exiting; the tmux `trap`/`exec $SHELL` workaround is dropped.
- Stays a bash script, works under bash and zsh.

## Approaches

Only one sensible way: drive herdr through its CLI. Alternatives (herdr's raw socket API, or a layout file) are heavier and no more stable; herdr has no declarative layout file that I found.

## Left to the builder

- Exact way to find an existing workspace for a directory (label plus pane cwds).
- JSON parsing (jq if available, otherwise another approach).
- What happens when no herdr server is running; verify and handle.
- README and usage-text updates for the herdr wording.
