# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing anything.** It has the rules for commits, PRs, testing, and what CI checks. This file describes how the repo is put together.

## Repository Overview

Personal dotfiles. GNU Stow symlinks `.config` into `~/.config` and `.claude` into `~/.claude`, so the files here are the live config on every machine that ran the installer. A broken file here breaks a real shell.

## Installation

`install.sh` is the only setup entry point. Piped (`curl | bash`), it clones this repo to `~/dotfiles` and re-runs the on-disk script. From a checkout, it:

- Installs dependencies. macOS: Homebrew if needed, then `BREW_PACKAGES` (stow, lazygit, tmux, neovim). Linux: `LINUX_PACKAGES` (git, stow, zsh, tmux) via apt, pacman, or dnf.
- Installs Oh My Zsh (to `~/.oh-my-zsh`) and Powerlevel10k when missing. The Oh My Zsh installer must be called with `ZDOTDIR` empty and `--keep-zshrc`, or it overwrites the symlinked `.zshrc`.
- Links `.config` and `.claude` with Stow. Files in the way are moved to `~/.dotfiles-backup/<timestamp>/`, never deleted.
- Adds `ZDOTDIR` to `~/.zshenv`. `ZDOTDIR` makes zsh skip `~/.zprofile`, so `.zshrc` puts Homebrew on `PATH` itself.

Flags: `--dry-run` (change nothing), `--link-only` (skip installs).

### Managing Configurations with Stow

`.config` is one Stow package. Its children (`zsh`, `tmux`, `nvim`, …) are what land in `~/.config`:

```bash
# Link, unlink, restow. Run from the repo root.
stow -t ~/.config .config
stow -D -t ~/.config .config
stow -R -t ~/.config .config
```

## Architecture & Structure

```
.config/
├── ghostty/           # Ghostty terminal config
├── lazygit/           # lazygit config
├── nvim/              # LazyVim config
├── opencode/agent/    # OpenCode agent prompts
├── tmux/              # tmux config
└── zsh/               # .zshrc, .p10k.zsh, completions, mouse fixes

.claude/
└── settings.json      # Claude Code settings (status line, plugins)

.github/
├── workflows/         # CI, Claude PR review
└── ISSUE_TEMPLATE/    # Bug, new-machine setup, config change
```

### OpenCode Agents (`.config/opencode/agent/`)

- Markdown files with YAML frontmatter: model, temperature, tools, permissions, mode
- companion (primary, read-only), senior-developer, solution-architect, code-reviewer, test-engineer, technical-writer, devops-engineer, diagram-specialist, requirements-analyst
- Bash permissions are granular, for example:

```yaml
permission:
  bash:
    "rm *": deny
    "sudo *": ask
    "*": allow
```

### Shell Environment

**Zsh** (`.config/zsh/.zshrc`):

- Powerlevel10k instant prompt must stay at the very top of `.zshrc`, and nothing above it may print or read from the terminal
- Oh My Zsh with the Powerlevel10k theme and the git plugin
- `.p10k.zsh` lives in `.config/zsh/` (ZDOTDIR) and is tracked, so a new machine gets the prompt without the wizard
- Machine-specific settings go in `.config/zsh/.zshrc.local` (gitignored)
- Sources `tmux.zsh` (`tmx`), `powerctl.zsh` and `sky.zsh` (generated completions), and `mouse.zsh` (stops stray mouse reports after sleep)
- Aliases: `n`, `ll`, `o`, `gaa`, `gcm`, `gpsh`, `gss`, `cc` (claude), `oc` (opencode), `dtable`, `dstart`

**Tmux** (`.config/tmux/tmux.conf`):

- Prefix `Ctrl+a`; splits `|` and `-`; navigate `h/j/k/l`; resize `H/J/K/L` (repeatable)
- Vi copy mode, mouse on, 10,000 lines of history, OSC 52 clipboard

## Notes for Future Modifications

- `~/.config/zsh` is a link into this repo, so zsh writes its history and `.zcompdump` here. They are gitignored. Keep it that way; history can contain secrets
- Tmux config lives at `~/.config/tmux/tmux.conf`, not the default location
- When the setup itself needs a new Homebrew package, add it to `BREW_PACKAGES` in `install.sh` (and `LINUX_PACKAGES` if it applies)
- Don't add shell aliases that bypass safety prompts (for example `--dangerously-skip-permissions`)
