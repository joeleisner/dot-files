# Harness Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip workstation-specific modules from the chezmoi repo, move SSH to a `config.d` layout with safer defaults, and make the 1Password agent socket path consistent and self-repairing on every apply.

**Architecture:** `~/.ssh/config` becomes a one-line `Include config.d/*`; harness-owned fragments (`00-1password.conf`, `99-defaults.conf`) live in `~/.ssh/config.d/`. One canonical agent path (`~/.1password/agent.sock`) is set once in `00-env`, and an every-apply `run_after` script repairs/verifies it per OS (macOS symlink, WSL relay service). Git-over-ssh opts out of multiplexing via `core.sshCommand`.

**Tech Stack:** chezmoi templates, bash, OpenSSH client config, systemd user units (WSL), Homebrew, GNU Stow (install only).

**Spec:** `docs/superpowers/specs/2026-11-12-harness-simplification-design.md`

## Global Constraints

- Work on branch `harness-simplification` (already created); do not touch `main`.
- Do NOT run `chezmoi apply` against the real home directory; verify with `chezmoi execute-template`, `chezmoi diff`/`apply --dry-run`, or a temp destination. The user applies later.
- Never delete or modify the user's rendered scripts in `~/.local/bin`; no `.chezmoiremove` entries.
- Canonical agent path is exactly `~/.1password/agent.sock` on every OS. No XDG relocation.
- No `ForwardAgent` and no `IdentitiesOnly` in tracked ssh config.
- ControlPath is exactly `~/.ssh/control/%C`; keep `private_dot_ssh/private_control/.keep`.
- 1Password is only used for the SSH agent and git signing; the ssh config text must not come from 1Password.
- No new tools besides `stow` (Homebrew). Prefer plain files over templates where no templating is needed.
- Commit message style follows the repo: `improvement: ...`, `chore: ...`, `docs: ...`.
- Temp files go in the scratchpad: `/tmp/claude-1000/-var-home-joel--local-share-chezmoi/5d8da6b8-18a1-4ef1-8546-9f199f509dc2/scratchpad` (referred to below as `$SCRATCH`).

## Review Focus

Failure modes the spec implies that are most likely to bite, each pinned to the task that owns it:

1. `config.d` is empty or missing: ssh must still work (Task 2).
2. An external `config.d` file without a numeric prefix sorts after `99-defaults.conf` and silently loses to it: documented, and demonstrated (Task 2, Task 6).
3. `SSH_AUTH_SOCK` inside an ssh session with a forwarded agent must not be clobbered (Task 4).
4. `~/.1password/agent.sock` exists as a regular file/directory on macOS: warn, never replace (Task 5).
5. Machine with no 1Password (headless): the repair script exits 0 silently (Task 5).

## File Structure

| Path | Action | Responsibility |
| :--- | :--- | :--- |
| `dot_local/bin/executable_{icover,icoverr,iname,isync,podify,switch-activity,switch-desktop,switch-monitors,switch-peripherals}.tmpl` | Delete | Workstation-only scripts |
| `.chezmoi.toml.tmpl` | Modify | Keep only git prompts + `onePassword.command` |
| `private_dot_ssh/private_config.tmpl` | Replace with `private_dot_ssh/private_config` | `Include config.d/*` only |
| `private_dot_ssh/private_config.d/00-1password.conf` | Create | `IdentityAgent` for canonical socket |
| `private_dot_ssh/private_config.d/99-defaults.conf` | Create | `Host *` defaults |
| `dot_config/git/executable_config.tmpl` | Modify | Add `core.sshCommand` |
| `dot_config/bash/bashrc.d/00-env` | Modify | Guarded `SSH_AUTH_SOCK` export |
| `dot_config/bash/bashrc.d/90-linux`, `dot_config/zsh/zshrc.d/90-zsh` | Modify | Remove socket logic |
| `dot_config/systemd/user/npiperelay.service` | Modify | Listen on canonical path |
| `run_onchange_after_setup-wsl-op-agent.tmpl` | Delete | Replaced by script below |
| `run_after_repair-1password-agent.tmpl` | Create | Every-apply repair + verify |
| `run_after_check-onepassword.tmpl` | Modify | Wording |
| `.chezmoitemplates/Brewfile-packages` | Modify | Add `stow` |
| `README.md` | Modify | Features, extension points, SSH guidance |

---

### Task 1: Remove workstation modules

**Files:**
- Delete: the nine `dot_local/bin/executable_*.tmpl` scripts listed above
- Modify: `.chezmoi.toml.tmpl`, `README.md` (the "Optional Feature Toggles" section only)
- Commit also: `docs/` (spec + this plan)

**Interfaces:**
- Produces: `.chezmoi.toml.tmpl` still renders with `git_name`, `git_email`, `git_signing_key_uri`, `ssh_conf_secret` (the last is removed in Task 2).

- [ ] **Step 1: Delete the nine scripts** with `git rm`. Confirm `ls ~/.local/bin` still contains the rendered copies afterwards.
- [ ] **Step 2: Edit `.chezmoi.toml.tmpl`** removing the `has_ipod`, `is_kde`, `at_home` prompts, the `ipod_*`, `peripheral_switch_device`, `monitor_bus_*` variables/prompts, and their `[data]` keys and comments. Leave `ssh_conf_secret` for Task 2.
- [ ] **Step 3: Remove the "Optional Feature Toggles" section** (heading through the module table and trailing `---`) from `README.md`.
- [ ] **Step 4: Verify.** Run `grep -rnE 'has_ipod|is_kde|at_home|ipod_|monitor_bus|peripheral_switch' . --exclude-dir=.git --exclude-dir=docs`; expected: no output. Run `chezmoi execute-template --init --promptString git_name=a,git_email=b,git_signing_key_uri=c,ssh_conf_secret=d < .chezmoi.toml.tmpl`; expected: valid TOML with only `[onePassword]` and the git/ssh keys under `[data]`.
- [ ] **Step 5: Commit**

```bash
git add -A docs dot_local .chezmoi.toml.tmpl README.md
git commit -m "improvement: Remove workstation-specific modules (ipod, kde, at-home)"
```

---

### Task 2: SSH `config.d` layout and defaults

**Files:**
- Delete: `private_dot_ssh/private_config.tmpl`
- Create: `private_dot_ssh/private_config`, `private_dot_ssh/private_config.d/00-1password.conf`, `private_dot_ssh/private_config.d/99-defaults.conf`
- Modify: `.chezmoi.toml.tmpl` (drop `ssh_conf_secret` prompt, `ssh_conf` data key, and the `# SSH Config` comment), `run_after_check-onepassword.tmpl` (message must mention only git commit signing)

**Interfaces:**
- Produces: effective ssh options for every host: `controlpath` under `~/.ssh/control/` using `%C`, `forwardagent no`, `serveraliveinterval 60`, `serveralivecountmax 3`, `addkeystoagent true`, `hashknownhosts yes`, `identityagent` = `~/.1password/agent.sock`.

- [ ] **Step 1: Write the check.** Create `$SCRATCH/ssh-check.sh` that builds a combined config from the repo files in glob order (`00-1password.conf`, optional extra fragment, `99-defaults.conf`), runs `ssh -G -F <combined> example.com`, and asserts: `controlpath` contains `/.ssh/control/` and no `%r`; `forwardagent no`; `serveraliveinterval 60`; `serveralivecountmax 3`; `addkeystoagent true`; `hashknownhosts yes`; `identityagent` ends in `/.1password/agent.sock`; no `identitiesonly yes`. (OpenSSH only honours relative `Include` under the real `~/.ssh`, so test by concatenation.)
- [ ] **Step 2: Run it; expect FAIL** (files do not exist).
- [ ] **Step 3: Create `private_config`** containing only `Include config.d/*`, and delete `private_config.tmpl`.
- [ ] **Step 4: Create `00-1password.conf`** with a short comment and a `Host *` block containing `IdentityAgent ~/.1password/agent.sock`. Create **`99-defaults.conf`** with a `Host *` block: `ControlMaster auto`, `ControlPath ~/.ssh/control/%C`, `ControlPersist 10m`, `ServerAliveInterval 60`, `ServerAliveCountMax 3`, `AddKeysToAgent yes`, `HashKnownHosts yes`. Add a header comment explaining that ordering matters (first value wins; external files need a prefix below `99`).
- [ ] **Step 5: Update `.chezmoi.toml.tmpl` and `run_after_check-onepassword.tmpl`** as described under Files.
- [ ] **Step 6: Run the check; expect PASS.** Then extend it with two Review Focus cases: (a) an extra fragment named `work.conf` (no prefix, sorted after `99-`) setting `ServerAliveInterval 5` for `example.com` loses to the defaults, proving the README rule is needed; (b) a config whose `Include` points at an empty directory still yields a working `ssh -G` (exit 0).
- [ ] **Step 7: Verify chezmoi sees the layout.** `chezmoi diff` (or `apply --dry-run --verbose --destination $SCRATCH/dest`) lists `.ssh/config`, `.ssh/config.d/00-1password.conf`, `.ssh/config.d/99-defaults.conf`; `.ssh/config.d` is 0700 and `.ssh/config` is 0600 in the destination.
- [ ] **Step 8: Commit**

```bash
git add -A private_dot_ssh .chezmoi.toml.tmpl run_after_check-onepassword.tmpl
git commit -m "improvement: ssh config.d layout with safer defaults"
```

---

### Task 3: Disable multiplexing for git-over-ssh

**Files:**
- Modify: `dot_config/git/executable_config.tmpl`

- [ ] **Step 1: Failing check.** Render with `chezmoi execute-template --init --promptString git_name=a,git_email=b,git_signing_key_uri=c < dot_config/git/executable_config.tmpl > $SCRATCH/gitconfig`, then `git config -f $SCRATCH/gitconfig core.sshCommand`; expected now: no value (exit 1).
- [ ] **Step 2: Add a `[core]` section** with `sshCommand = ssh -o ControlMaster=no -o ControlPath=none`, placed before `[gpg]` to keep sections grouped sensibly.
- [ ] **Step 3: Re-render and check;** expected output exactly `ssh -o ControlMaster=no -o ControlPath=none`, and the rest of the file unchanged (diff against the earlier render shows only the new section).
- [ ] **Step 4: Commit** `improvement: Disable ssh multiplexing for git`.

---

### Task 4: Single guarded `SSH_AUTH_SOCK`

**Files:**
- Modify: `dot_config/bash/bashrc.d/00-env`, `dot_config/bash/bashrc.d/90-linux`, `dot_config/zsh/zshrc.d/90-zsh`

**Interfaces:**
- Produces: after sourcing `00-env`, `SSH_AUTH_SOCK=$HOME/.1password/agent.sock` iff `[ -S ~/.1password/agent.sock ]` and `SSH_CONNECTION` is unset; otherwise `SSH_AUTH_SOCK` is left untouched. `95-ssh` (unchanged) depends on this.

- [ ] **Step 1: Failing checks** in `$SCRATCH/sock-check.sh`, each in a fresh `bash -c` with a temp `HOME`, creating a real unix socket via `python3 -I -c 'import socket,sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' <path>`:
  - socket present, `SSH_CONNECTION` unset, `SSH_AUTH_SOCK` unset → after `. 00-env`, equals `$HOME/.1password/agent.sock`
  - socket present, `SSH_CONNECTION=1.2.3.4` and `SSH_AUTH_SOCK=/forwarded.sock` → unchanged (Review Focus 3)
  - socket absent → `SSH_AUTH_SOCK` stays unset
  Run; expect the first case to FAIL (nothing sets it in `00-env` yet).
- [ ] **Step 2: Add the guarded export to `00-env`** (after the XDG block, with a comment); delete the 1Password block from `90-linux` and from `90-zsh` (keep their mise activation).
- [ ] **Step 3: Run the checks; expect all PASS.** Also `bash -n` each edited file and confirm `zsh/zshrc.d/symlink_00-env` still points at the bash `00-env`.
- [ ] **Step 4: Commit** `improvement: Set SSH_AUTH_SOCK once, guarded`.

---

### Task 5: WSL relay path and every-apply repair script

**Files:**
- Modify: `dot_config/systemd/user/npiperelay.service`
- Delete: `run_onchange_after_setup-wsl-op-agent.tmpl`
- Create: `run_after_repair-1password-agent.tmpl`

**Interfaces:**
- Consumes: canonical path from Task 4; includeTemplate `onepassword-cmd` (resolves to `op` or `op.exe`).
- Produces: a script that always exits 0, is idempotent, and prints `⚠️`/`❌`-prefixed diagnoses (the repo's existing emoji style) to stderr.

- [ ] **Step 1: Look up the macOS socket path.** Verify against current 1Password docs (Context7 or the 1Password developer docs) that the macOS agent socket is `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`; if different, use the documented path and note it in the commit message.
- [ ] **Step 2: Update `npiperelay.service`:** `UNIX-LISTEN:%h/.1password/agent.sock`; `ExecStartPre` must `mkdir -p %h/.1password` and `rm -f %h/.1password/agent.sock`.
- [ ] **Step 3: Write failing checks** in `$SCRATCH/repair-check.sh`. Render the template for each OS and run it under a temp `HOME` with stub `ssh-add`, `systemctl`, `op`, `op.exe` executables first on `PATH` that record calls. Cases:
  - No 1Password detected (no app dir, no `op`/`op.exe`): exit 0, no output, no stub calls (Review Focus 5)
  - macOS, socket path absent: symlink created pointing at the Group Containers socket; second run changes nothing (idempotent)
  - macOS, `~/.1password/agent.sock` is a regular file: warning printed, file untouched (Review Focus 4)
  - macOS, symlink pointing elsewhere: re-pointed
  - WSL (`WSL_DISTRO_NAME` set): `daemon-reload` and `enable --now` called; if canonical socket missing, `restart` called; stale `~/.ssh/agent.sock` removed
  - Verification: stub `ssh-add -l` exit 2 → "socket missing/unreachable" diagnosis; exit 1 → "no keys; is 1Password unlocked?"; exit 0 → silent; script exit status always 0
  Render with `chezmoi execute-template --override-data` or equivalent for `.chezmoi.os`; if override flags are unavailable, split OS-specific bodies into separate `{{ if }}` blocks and render each by editing a scratch copy. Run; expect FAIL (script does not exist).
- [ ] **Step 4: Create `run_after_repair-1password-agent.tmpl`** (runs every apply, no `onchange` hash). Structure, in this order:
  1. `has_onepassword`: true on macOS if `/Applications/1Password.app` exists or the `onepassword-cmd` binary is on `PATH`; on Linux/WSL if that binary or `1password` is on `PATH` or the relay unit is already installed. If false, `exit 0` silently.
  2. macOS only: ensure `~/.1password` exists and `agent.sock` there is a symlink to the Group Containers socket (create if absent, re-point if a different symlink, warn and leave alone if it is anything else).
  3. WSL only: carry over the existing npiperelay.exe build/link logic from the deleted script unchanged (tool checks, `go build` via `mise exec`, link into `~/.local/bin`); then `systemctl --user daemon-reload`, `enable --now npiperelay.service`, `restart` if the canonical socket is missing, and `rm -f ~/.ssh/agent.sock`.
  4. All OSes: `verify_agent` runs `SSH_AUTH_SOCK=$HOME/.1password/agent.sock ssh-add -l` and maps exit codes to the diagnoses above; also reports `ssh-add` not installed.
  End with `exit 0`; no `set -e` aborts the apply for diagnosable problems.
- [ ] **Step 5: Delete the old `run_onchange_after_setup-wsl-op-agent.tmpl`** with `git rm` (the service file itself stays chezmoi-managed).
- [ ] **Step 6: Run the checks; expect PASS.** Also run `shellcheck` on each rendered output.
- [ ] **Step 7: Commit** `improvement: Self-healing 1Password agent setup on every apply`.

---

### Task 6: Stow package and README

**Files:**
- Modify: `.chezmoitemplates/Brewfile-packages`, `README.md`

- [ ] **Step 1: Add `brew "stow"`** to `Brewfile-packages` under a short comment (`# Linking external projects into bashrc.d / config.d`). Verify with `grep -n stow .chezmoitemplates/Brewfile-packages`.
- [ ] **Step 2: Update the README:**
  - Requirements: 1Password desktop app + CLI, for the SSH agent and git signing only.
  - Features list item 6 reworded to the agent and git signing (not "ssh config").
  - New "Extending" section: `~/.config/bash/bashrc.d/` and `~/.ssh/config.d/`, the numeric-prefix convention, and a **prominent** rule that external ssh fragments must be prefixed below `99` (first value wins; `99-defaults.conf` is last).
  - New "Linking external projects" section: GNU Stow with `--no-folding` and why (it links files instead of replacing the harness-owned directory); note stowed ssh files must be mode 0600/0644 (ssh rejects group/world-writable config).
  - New "SSH tips" section: per-host `ForwardAgent yes` only for trusted hosts where git/ssh is run from the host; prefer `ProxyJump` for bastions; `IdentitiesOnly yes` plus `IdentityFile <pubkey>` per host if "Too many authentication failures" appears.
  - Remove the WSL note claiming generated files lack 1Password details if no longer true (the ssh config no longer depends on 1Password); keep the note that the relay setup runs on WSL.
- [ ] **Step 3: Verify:** `grep -n -iE 'ssh_conf|1Password-powered ssh|Optional Feature' README.md` returns nothing; skim the rendered README for the 99-prefix rule.
- [ ] **Step 4: Commit** `improvement: Install stow, document extension points`.

---

### Task 7: Whole-branch verification (no real apply)

- [ ] **Step 1:** `chezmoi apply --dry-run --verbose` on the real home. Expect: `.ssh/config`, `.ssh/config.d/*`, git config, shell files change; nothing under `~/.local/bin` is touched or removed; no run script errors in dry-run output.
- [ ] **Step 2:** Re-run all `$SCRATCH` checks (ssh, sock, repair, git) and `shellcheck`/`bash -n` on every shell file changed on the branch (`git diff --name-only main`).
- [ ] **Step 3:** `grep -rnE '1password.*(ssh_conf|onepasswordRead .ssh)|ForwardAgent yes|IdentitiesOnly' private_dot_ssh dot_config .chezmoi.toml.tmpl` returns nothing.
- [ ] **Step 4:** `git status` is clean, `git log main..` shows one commit per task. Report results to the user; do not push or open the PR unless asked.

---

## Self-review notes

- **Spec coverage:** removals → T1; ssh layout/defaults/ordering/permissions → T2, T6; git multiplexing → T3; canonical socket + guarded env → T4; WSL path, macOS symlink, self-heal, non-destructive repair, headless skip, wording → T2/T5; Stow + README → T6; verification and no-apply constraint → T7.
- **Type consistency:** canonical path string `~/.1password/agent.sock` is identical in T2, T4, T5; `onepassword-cmd` template name matches the repo.
- **Known risk for the executor:** `ssh` only honours relative `Include` under the real `~/.ssh`, so T2 tests by concatenation; final confirmation that `Include` resolves happens when the user applies for real.
