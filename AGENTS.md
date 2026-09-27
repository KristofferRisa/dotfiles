# AGENTS.md

Guidance for AI coding agents (Claude Code, OpenCode, and others) working in this repository.

**Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing anything.** It has the rules for commits, PRs, testing, and what CI checks. This file describes how the repo is put together.

## Repository Overview

Personal dotfiles. GNU Stow symlinks `.config` into `~/.config` and `.claude` into `~/.claude`, so the files here are the live config on every machine that ran the installer. A broken file here breaks a real shell.

## Installation

`install.sh` is the only setup entry point. Piped (`curl | bash`), it clones this repo to `~/dotfiles` and re-runs the on-disk script. From a checkout, it:

- Installs dependencies. macOS: Homebrew if needed, then `BREW_PACKAGES` (stow, lazygit, tmux, neovim). Linux: `LINUX_PACKAGES` (git, stow, zsh, tmux) via apt, pacman, or dnf.
- Installs Oh My Zsh (to `~/.oh-my-zsh`) and Powerlevel10k when missing. The Oh My Zsh installer must be called with `ZDOTDIR` empty and `--keep-zshrc`, or it overwrites the symlinked `.zshrc`.
- Links `.config` and `.claude` with Stow. Files in the way are moved to `~/.dotfiles-backup/<timestamp>/`, never deleted.
- Adds `ZDOTDIR` to `~/.zshenv`. `ZDOTDIR` makes zsh skip `~/.zprofile`, so `.zshrc` puts Homebrew on `PATH` itself.
- Links `~/.zshrc` to `~/.config/zsh/.zshrc` (backing up whatever was there). zsh never reads it while `ZDOTDIR` is set, but Claude Code's shell snapshot and tool installers (nvm, rustup, grok) hardcode `~/.zshrc`; a stale copy there gives them a different shell than the terminal. Lines those installers append land in the repo `.zshrc`, so they show up in `git status`.

Flags: `--dry-run` (change nothing), `--link-only` (skip installs), `--update` (`git pull --ff-only` first, then install and link).

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
├── git/               # Global git config + allowed_signers (SSH commit signing)
├── lazygit/           # lazygit config
├── nvim/              # LazyVim config
├── tmux/              # tmux config
└── zsh/               # .zshrc, .p10k.zsh, completions, mouse fixes

.claude/
├── settings.json      # Claude Code settings (status line, plugins)
└── statusline/        # Status line: bash + jq, no npm packages

.github/
├── workflows/         # CI, PR labeler
└── ISSUE_TEMPLATE/    # Bug, new-machine setup, config change

tests/statusline/      # Fixture tests for the status line cost math
```

### Shell Environment

**Zsh** (`.config/zsh/.zshrc`):

- Powerlevel10k instant prompt must stay at the very top of `.zshrc`, and nothing above it may print or read from the terminal
- Oh My Zsh with the Powerlevel10k theme and the git plugin
- `.p10k.zsh` lives in `.config/zsh/` (ZDOTDIR) and is tracked, so a new machine gets the prompt without the wizard
- Machine-specific settings go in `.config/zsh/.zshrc.local` (gitignored)
- Sources `tmux.zsh` (`tmx`), `powerctl.zsh` and `sky.zsh` (generated completions), and `mouse.zsh` (stops stray mouse reports after sleep)
- Exports `CLAUDE_CODE_ENABLE_TELEMETRY=1`; the OTel exporter and endpoint go in `.zshrc.local`
- Aliases: `n`, `ll`, `o`, `gaa`, `gcm`, `gpsh`, `gss`, `cc` (claude), `oc` (opencode), `dtable`, `dstart`

**Tmux** (`.config/tmux/tmux.conf`):

- Prefix `Ctrl+a`; splits `|` and `-`; navigate `h/j/k/l`; resize `H/J/K/L` (repeatable)
- Vi copy mode, mouse on, 10,000 lines of history, OSC 52 clipboard

### Git (`.config/git/`)

- git reads `~/.config/git/config` natively. It signs every commit and tag with SSH (`~/.ssh/id_ed25519.pub`)
- `allowed_signers` lists the public keys trusted for local verification. Add each machine's key
- Machine-specific overrides go in `config.local` (gitignored, included last)

### Claude Code status line (`.claude/statusline/`)

- `statusline.sh` reads Claude Code's JSON on stdin and prints two lines: folder, git, model and effort, and context on the first; session cost, today's cost, cache hit rate, and 5h/7d rate limits on the second
- `usage.jq` sums every transcript under `~/.claude/projects` (subagent files too). It counts each API response once (`message.id` + `requestId`) and prices 5-minute and 1-hour cache writes and fast mode separately
- `pricing.json` is the only place prices live. A model is priced by the longest key it starts with. An unknown model shows `~` and "unknown price"; never guess a price. Update it when a model launches, from Anthropic's pricing docs
- `render.jq` draws the output (Catppuccin Mocha colours; honours `NO_COLOR`)
- `statusline.sh --report` prints today's cost by model. `CLAUDE_STATUSLINE_DEBUG=1` saves the raw input to `~/.cache/claude-statusline/last-input.json`
- Change the pricing math only together with `tests/statusline/`, whose expected dollar amounts were worked out by hand

## Notes for Future Modifications

- `.config/.stow-local-ignore` keeps zsh state (history, `.zcompdump`) and machine-local files from being linked. It replaces Stow's defaults, so keep those listed
- `~/.config/zsh` is a link into this repo, so zsh writes its history and `.zcompdump` here. They are gitignored. Keep it that way; history can contain secrets
- Tmux config lives at `~/.config/tmux/tmux.conf`, not the default location
- The status line needs `jq`. It ships with macOS 15+, and the installer adds it everywhere else
- When the setup itself needs a new Homebrew package, add it to `BREW_PACKAGES` in `install.sh` (and `LINUX_PACKAGES` if it applies)
- Don't add shell aliases that bypass safety prompts (for example `--dangerously-skip-permissions`)
