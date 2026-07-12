# Joel's Dot Files

My minimal, XDG-compliant, shell-impartial dot files + setup.

## Features

1. Works w/ Bash or ZSH
2. Homebrew install
3. Development dependencies and overrides
4. Terminal bling

## Installation

During initial setup, the following will be ran:

1. Check for required dependencies
2. Install Homebrew
3. Install packages (for shell bling and web development)
4. Install overrides (for dev-critical packages)

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io/lb)" -- init --apply --branch 2.0.0 https://github.com/joeleisner/dot-files.git
```

## Optional Feature Toggles

This configuration includes specialized scripts for my environments and locations. These are disabled by default and entirely optional.

To enable or disable these features, you can configure your local Chezmoi state variables.

### Available Modules

| Module | Description |
| :--- | :--- |
| `has_ipod` | Custom shell utilities for batch-tagging music, syncing FLAC files, and managing Rockbox iPod builds. |
| `is_kde` | Automation scripts for the KDE Plasma desktop. |
| `at_home` | Automation scripts for at-home stuff |

---

### How to Enable Features

Run `chezmoi edit-config` to open your local configuration file, and add your desired feature flags under the `data` block:

```toml
[data]
	has_ipod = true
	is_kde = false
	at_home = true
```
