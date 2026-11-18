# `proj -g`: the Herdr desktop app backend — design

Date: 2026-11-17

## Intent

Joel moved from the terminal `herdr` to the Herdr desktop app (terminals run in `herdr-core`/`hc`, the window is driven with `herdr-app`). `proj -s` only talks to the terminal herdr, so `proj` gets a second backend and keeps both.

## Behaviour

- `proj -g [project]` is `-s` against the app: focus the project's space, or create it with tabs `agent`, `edit`, `shell` (agent focused). `-d` creates it without focusing.
- `PROJ_UI=gui|tui` picks the backend for `-s` (default `tui`). `-g` and `-t` each imply `-s` and force the app or the terminal version. A flag beats the env var.
- Lookup order is the same as `-s`: a space whose name equals the argument, then a space whose `folder` equals the resolved directory, then create.
- Space name is the directory basename, with a `cksum` suffix if a space of that name already exists.
- If the app isn't open, `proj` opens it (`open -a Herdr`, `-g` for `-d`) and waits for `herdr-app ls`.
- Focusing selects the space and its agent tab, and raises the window with `open -a Herdr` when run outside it (no `$HC_TERMINAL_ID`).

## Findings that shaped it

- `herdr-app do space.new/tab.new --argv` runs the program inside a login shell that outlives it, so tabs survive `hx` or the agent exiting and no `exec $SHELL` wrapper is needed. `argv` isn't a shell, so commands are wrapped as `["sh","-c",...]`.
- A space's `folder` is where its first terminal started, not its cwd. Spaces made by hand can have a stale folder (they still open by name); spaces `proj` makes always have the right one.
- `space.select` and `tab.select` take `--id`.
- `space.close` ends the tab terminals it created in testing, but a terminal that had already exited and been replaced lingered as a finished `hc` terminal; `hc kill` clears it.

## Non-goals

- No change to the default (no-flag) `proj`, to `PROJ_AGENT`, or to the terminal herdr behaviour.
- `proj` never closes spaces, tabs or terminals.
