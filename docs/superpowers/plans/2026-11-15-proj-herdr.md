# `proj -s` on herdr Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** `proj -s` creates or focuses a herdr workspace (tabs agent, edit, shell) instead of a tmux session.

**Architecture:** Drive herdr through its JSON CLI (`workspace`, `tab`, `pane`), parse with `jq`. If no herdr server is running, start one headless (`herdr server`) and wait for its socket. Outside herdr, attach with plain `herdr`.

**Tech Stack:** bash, herdr 0.9.5, jq.

**Spec:** `docs/superpowers/specs/2026-11-15-proj-herdr-design.md`

## Global Constraints

- Tab order: `agent`, `edit`, `shell`; agent tab focused.
- Agent command is `$PROJ_AGENT`, default `claude --continue || claude`.
- `proj` without `-s` is unchanged; `-d` creates without focusing or attaching.
- Never close a workspace, tab or pane. No tmux fallback.

## Review Focus

- Existing workspace for the directory: focus it, never create a duplicate.
- Same basename, different directory: distinct label (basename plus 4-char cksum).
- No herdr server running: start one, then proceed.
- herdr or jq missing: clear `proj:` error, nothing half-created.

### Task 1: Rewrite the session half of `dot_local/bin/executable_proj`

**Files:**
- Modify: `dot_local/bin/executable_proj`
- Modify: `README.md` (Terminal workspace section: `proj -s` wording)

**Interfaces:**
- Produces: `ensure_server`, `find_workspace <dir>` (prints workspace id or nothing), `workspace_label <dir>`, `ensure_workspace <dir>` (prints workspace id), `go_to_workspace <id>`.

- [ ] **Step 1:** Replace the tmux functions with the herdr ones above; update usage text and the `-s` precondition check (`herdr`, `jq`).
- [ ] **Step 2:** Verify with a scratch herdr session (`--session`), never the user's default session: create, re-run (no duplicate), `-d`, label collision, mise-tasks tab.
- [ ] **Step 3:** `shellcheck`/`bash -n`; update README blurb.
- [ ] **Step 4:** `chezmoi apply` the script locally; do not commit until the user confirms.
