# Dotfiles

Personal dotfiles for system configuration management, designed for both local machines and cloud development environments (Coder).

## Features

- 🚀 **Cross-platform**: Works on macOS and Linux (Ubuntu, Debian, Arch)
- ⚡ **Fast setup**: Pre-built Docker images for Coder (~2-5s startup)
- 🔧 **Modern tools**: neovim, tmux, zsh, bun, bitwarden-cli
- 🔗 **GNU Stow**: Clean symlink management
- 📦 **Idempotent**: Safe to run multiple times

## What's Included

### Core Tools
- **git** - Version control
- **neovim** with LazyVim - Modern text editor
- **tmux** - Terminal multiplexer
- **zsh** with Oh-My-Zsh - Enhanced shell
- **stow** - Dotfiles management

### Development Tools
- **bun** - Fast JavaScript runtime
- **bitwarden-cli** - Secret management
- **ripgrep, fzf** - Search utilities

### Configurations
- Zsh with Powerlevel10k theme
- Tmux with custom keybindings
- Ghostty terminal emulator
- Yabai window manager (macOS)
- Custom Claude Code agents

---

## Installation

### Local Machine (macOS, Linux)

#### Quick Install (One-liner)
```bash
curl -fsSL https://raw.githubusercontent.com/kristofferrisa/dotfiles/main/install.sh | bash
```

#### Manual Install
```bash
# Clone the repository
git clone --recurse-submodules https://github.com/kristofferrisa/dotfiles.git ~/dotfiles

# Run installation
cd ~/dotfiles
./install.sh
```

#### What It Does
1. Detects your OS (macOS, Ubuntu/Debian, Arch)
2. Installs required packages via package manager
3. Installs Bun.sh and Bitwarden CLI
4. Clones LazyVim starter configuration
5. Links dotfiles to `~/.config/` using GNU Stow

#### Options
```bash
./install.sh --help              # Show help
./install.sh --skip-packages     # Only link dotfiles (skip installs)
./install.sh --coder             # Coder mode (for pre-built images)
```

---

## Coder Setup

For cloud development environments using [Coder](https://coder.com/).

### Quick Start

1. **Build Docker image**:
   ```bash
   docker build -t kristofferrisa/coder-env:latest -f Dockerfile.coder .
   docker push kristofferrisa/coder-env:latest
   ```

2. **Use Terraform template**:
   - Copy `coder-example.tf` to your Coder templates
   - Update `docker_image` variable
   - Push to Coder: `coder templates push dotfiles coder-example.tf`

3. **Create workspace**:
   ```bash
   coder create my-workspace --template=dotfiles
   ```

**See [CODER.md](./CODER.md) for detailed instructions.**

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

### Bitwarden CLI

```bash
# Login (first time)
bw login

# Unlock vault
export BW_SESSION=$(bw unlock --raw)

# Get password
bw get password github.com
```

### Custom Scripts

**fabyt** - Extract knowledge from YouTube videos:
```bash
fabyt <YouTube-URL>
```

---

## Repository Structure

```
dotfiles/
├── install.sh              # Cross-platform installation script
├── Dockerfile.coder        # Docker image for Coder environments
├── coder-example.tf        # Terraform template for Coder
├── brew-install.sh         # Homebrew packages (macOS)
├── .config/                # Application configurations
│   ├── zsh/                # Zsh configuration
│   ├── tmux/               # Tmux configuration
│   ├── ghostty/            # Ghostty terminal config
│   ├── yabai/              # Yabai window manager
│   └── opencode/           # OpenCode agent configs
├── .claude/                # Claude Code agents
│   ├── agents/             # Custom agents
│   └── settings.json       # Claude Code settings
└── bin/                    # Custom scripts
    └── fabyt               # YouTube knowledge extractor
```

---

## Updating Dotfiles

### Local Machine
```bash
cd ~/dotfiles
git pull
./install.sh --skip-packages  # Only re-link configs
```

### Coder Workspace
Dotfiles are automatically updated on workspace restart, or manually:
```bash
cd ~/dotfiles
git pull
./install.sh --coder
```

---

## Platform-Specific Notes

### macOS
- Uses **Homebrew** for package management
- Automatically installs Homebrew if not present
- Includes Yabai window manager config
- Ghostty terminal emulator supported

### Linux
- Supports **apt** (Ubuntu/Debian) and **pacman** (Arch/Manjaro)
- Requires `sudo` for package installation
- Works in Docker containers (Coder)

### Coder
- Uses pre-built Docker image (fast startup)
- Skip package installation with `--coder` flag
- Dotfiles linked at workspace creation
- See [CODER.md](./CODER.md) for details

---

## Troubleshooting

### Install script fails
```bash
# Check OS detection
./install.sh --help

# Try skip packages (if deps already installed)
./install.sh --skip-packages
```

### Stow conflicts
```bash
# Backup existing configs
mv ~/.config ~/.config.backup

# Re-run install
./install.sh
```

### LazyVim not working
```bash
# Remove and reinstall
rm -rf ~/.config/nvim
./install.sh
nvim  # Plugins will install on first launch
```

---

## Documentation

- **[MIGRATION_PLAN.md](./MIGRATION_PLAN.md)** - Migration plan and progress tracking
- **[CODER.md](./CODER.md)** - Detailed Coder setup and usage
- **[CLAUDE.md](./CLAUDE.md)** - Repository overview and architecture

---

## Customization

### Adding Packages

Edit `install.sh` and add to the packages array:
```bash
packages=(git curl wget neovim tmux stow YOUR_PACKAGE)
```

### Modifying Configs

Configs are in `.config/`. After editing:
```bash
cd ~/dotfiles
stow -R -t ~/.config .config/
```

### Coder Image

Edit `Dockerfile.coder` and rebuild:
```bash
docker build -t kristofferrisa/coder-env:latest -f Dockerfile.coder .
docker push kristofferrisa/coder-env:latest
```

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
- [LazyVim](https://www.lazyvim.org/)
- [Coder](https://coder.com/docs)
- [Bitwarden CLI](https://bitwarden.com/help/cli/)
