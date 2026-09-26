# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for system configuration management. It uses GNU Stow for symlink management and contains configurations for shell, terminal emulator, window manager, and development tools. The repository also includes a custom Claude Code workspace setup and OpenCode agent configurations.

## Installation & Setup Commands

### Initial Installation

```bash
# Install dotfiles and dependencies
./install.sh
```

`install.sh` is the only setup entry point. Piped (`curl | bash`), it clones this repo to `~/dotfiles` and re-runs the on-disk script. From a checkout, it:

- Installs GNU Stow. macOS uses Homebrew and installs Homebrew first if needed, plus `lazygit`. Linux uses apt, pacman, or dnf for `git`, `stow`, and `zsh`.
- Installs Oh My Zsh (to `~/.oh-my-zsh`) and Powerlevel10k when they are missing. The Oh My Zsh installer must be called with `ZDOTDIR` empty and `--keep-zshrc`, or it overwrites the symlinked `.zshrc`.
- Symlinks the `.config` package to `~/.config` and `.claude` to `~/.claude`.
- Writes `ZDOTDIR` and a Homebrew `shellenv` snippet to `~/.zshenv`. `ZDOTDIR` makes zsh skip `~/.zprofile`.

### Managing Configurations with Stow

`.config` is one Stow package. Its children (`zsh`, `tmux`, `nvim`, …) are what land in `~/.config`:

```bash
# Link, unlink, restow. Run from the repo root.
stow -t ~/.config .config
stow -D -t ~/.config .config
stow -R -t ~/.config .config
```

## Architecture & Structure

### Configuration Organization

```
.config/
├── opencode/          # OpenCode agent configurations
│   └── agent/         # Agent prompt files (companion, senior-developer, etc.)
├── tmux/              # Tmux configuration and scripts
├── zsh/               # Zsh shell configuration
├── ghostty/           # Ghostty terminal emulator config
└── yabai/             # Yabai window manager config

.claude/
└── settings.json      # Claude Code settings

```

### Agent System Architecture

**OpenCode Agents** (`.config/opencode/agent/`):

- Defined as markdown files with YAML frontmatter
- Include: companion, senior-developer, solution-architect, code-reviewer, test-engineer, technical-writer, devops-engineer, diagram-specialist, requirements-analyst
- Primary agent is `companion` (read-only, research-focused)
- Specialized agents have different tool permissions and capabilities

Agent configurations specify:

- Model selection and temperature
- Available tools (write, edit, bash, webfetch, read, etc.)
- Permission policies (bash command restrictions)
- Operational mode (primary/specialized)

### Shell Environment

**Zsh Configuration** (`.config/zsh/.zshrc`):

- Oh-My-Zsh with Powerlevel10k theme
- Git plugin enabled
- Key aliases:
  - `n` - Open neovim in current directory
  - `cc` - Claude Code, `oc` - OpenCode
  - `gaa` - Git add all
  - `gcm` - Git commit with message
  - `gpsh` - Git push
  - `gss` - Git status short
  - Docker shortcuts: `dtable`, `dstart`

**Tmux Configuration** (`.config/tmux/tmux.conf`):

- Prefix: `Ctrl+a` (instead of default Ctrl+b)
- Vim keybindings in copy mode
- Custom split shortcuts: `|` (vertical), `-` (horizontal)
- Pane navigation: `h/j/k/l`
- Pane resizing: `Ctrl+a` then `H/J/K/L` (repeatable)
- Mouse support enabled
- History limit: 10,000 lines

## Development Workflow

### Adding New Configurations

1. Place config files in `.config/<application>/`
2. Restow the package: `stow -R -t ~/.config .config`
3. Verify `~/.config/<application>` is a symlink into this repo
4. Commit changes to repository

### Modifying Agents

**OpenCode agents**: Edit markdown files in `.config/opencode/agent/`

- Update YAML frontmatter for model, temperature, tools, permissions
- Modify agent personality and capabilities in markdown body

## Key Configuration Patterns

### Permission-Based Agent Design

Agents use granular permission controls:

```yaml
permission:
  bash:
    "rm *": deny
    "rm -*": deny
    "sudo *": ask
    "*": allow
```

### Frontmatter Standards

Markdown files follow consistent frontmatter patterns:

- Agent configs: description, mode, model, temperature, tools, permissions
- Output files (fabyt): tags array, url metadata
- Documentation: title, date, tags

### Stow-Based Linking

Configurations are NOT copied but symlinked:

- Allows editing configs in dotfiles repo directly
- Changes immediately affect active system
- Easy to version control and sync across machines

## Notes for Future Modifications

- The companion agent is read-only focused (write: false, edit: false)
- Other OpenCode agents have write capabilities for code implementation
- Tmux config sources from `~/.config/tmux/tmux.conf` (not default location)
- Zsh config sources tmux.zsh for tmux-specific shell integration
- Custom scripts in `bin/` should include dependency checks and help text
- When adding a Homebrew dependency of the setup itself, add it to `BREW_PACKAGES` in `install.sh`
