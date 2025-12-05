# Dotfiles

Personal dotfiles for system configuration management using GNU Stow.

## Philosophy

Simple, focused dotfiles repository following UNIX principles:

- **One responsibility**: Link configuration files
- **No package installation**: Install tools yourself
- **GNU Stow**: Clean symlink management
- **Version controlled**: Track all config changes

---

## Prerequisites

Install these tools before running the install script:

### Required

- **GNU Stow** - For linking dotfiles
  - macOS: `brew install stow`
  - Ubuntu: `sudo apt install stow`
  - Arch: `sudo pacman -S stow`

### Recommended Tools

The configurations in this repo are designed for:

- **git** - Version control
- **zsh** with Oh-My-Zsh - Enhanced shell
- **tmux** - Terminal multiplexer
- **neovim** - Modern text editor
- **ghostty** - Terminal emulator

Install these separately using your system's package manager.

---

## Installation

### Quick Start

```bash
# Clone the repository
git clone https://github.com/kristofferrisa/dotfiles.git ~/dotfiles

# Link dotfiles
cd ~/dotfiles
./install.sh
```

### What It Does

The install script:

1. Checks if GNU Stow is installed
2. Checks for conflicts with existing files
3. Creates symlinks from `.config/*` to `~/.config/`

**That's it.** No package installation, no setup wizards, just linking configs.

### Output

```
Checking for conflicts...
Linking dotfiles...
Done. Dotfiles linked to ~/.config/
```

If conflicts are detected, backup your existing `~/.config/` files first.

---

## What's Included

### Configurations

```
.config/
├── ghostty/       # Ghostty terminal emulator config
├── nvim/          # Neovim configuration
├── opencode/      # OpenCode agent configurations
├── tmux/          # Tmux configuration and keybindings
└── zsh/           # Zsh shell with Oh-My-Zsh
```

---

## Usage

### Zsh Aliases

Key aliases from `.config/zsh/.zshrc`:

```bash
n         # Open neovim in current directory
gaa       # git add --all
gcm       # git commit -m
gpsh      # git push
gss       # git status -s
```

### Tmux Keybindings

- **Prefix**: `Ctrl+a` (instead of default Ctrl+b)
- **Split vertical**: `Ctrl+a |`
- **Split horizontal**: `Ctrl+a -`
- **Navigate panes**: `Ctrl+a h/j/k/l`
- **Resize panes**: `Ctrl+a H/J/K/L` (hold Ctrl)
- **Copy mode**: `Ctrl+a [` (vim keybindings)

### Neovim

This repo includes nvim configuration. To use it:

1. Install neovim: `brew install neovim` (macOS) or your package manager
2. Link configs: `./install.sh`
3. Launch nvim: plugins will install on first launch

---

## Repository Structure

```
dotfiles/
├── install.sh              # Link dotfiles using Stow (37 lines)
├── .config/                # Application configurations
│   ├── ghostty/            # Terminal emulator
│   ├── nvim/               # Neovim editor
│   ├── opencode/           # OpenCode agents
│   ├── tmux/               # Terminal multiplexer
│   ├── yabai/              # Window manager (macOS)
│   └── zsh/                # Shell configuration
├── README.md               # This file
```

---

## Updating Dotfiles

```bash
cd ~/dotfiles
git pull
./install.sh  # Re-link configs
```

GNU Stow will update symlinks automatically.

---

## Modifying Configurations

Since configs are symlinked, you can edit them in place:

```bash
# Edit config in either location
nvim ~/.config/zsh/.zshrc
# OR
nvim ~/dotfiles/.config/zsh/.zshrc
# Both point to the same file!

# Commit changes
cd ~/dotfiles
git add .config/zsh/.zshrc
git commit -m "Update zsh config"
git push
```

---

## Troubleshooting

### "GNU Stow not installed"

```bash
# macOS
brew install stow

# Ubuntu/Debian
sudo apt install stow

# Arch
sudo pacman -S stow
```

### "Conflicts detected"

Backup existing configs:

```bash
mv ~/.config ~/.config.backup
./install.sh
```

Or manually resolve conflicts:

```bash
# Remove specific conflicting file
rm ~/.config/zsh/.zshrc
./install.sh
```

### Unlinking Configs

```bash
cd ~/dotfiles
stow -D -t ~/.config .config/
```

---

## Design Principles

1. **Do one thing well**: Link dotfiles, nothing more
2. **Minimal complexity**: 37 lines of shell script
3. **No hidden magic**: Clear, readable code
4. **Fail fast**: Exit on errors with helpful messages
5. **Composable**: Works with your existing tools

---

## Contributing

This is a personal dotfiles repository, but feel free to:

- Fork for your own use
- Open issues for bugs
- Suggest improvements via PRs

---

## License

MIT License - Use as you wish.

---

## Resources

- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html)
- [Oh-My-Zsh](https://ohmyz.sh/)
- [Neovim](https://neovim.io/)
- [Tmux](https://github.com/tmux/tmux/wiki)
