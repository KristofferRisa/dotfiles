#!/bin/bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
CODER_MODE=false
SKIP_PACKAGES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --coder)
            CODER_MODE=true
            SKIP_PACKAGES=true
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --coder          Run in Coder mode (skip package installation)"
            echo "  --skip-packages  Skip package installation (only link dotfiles)"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

OS=$(detect_os)
log_info "Detected OS: $OS"

if [[ "$CODER_MODE" == true ]]; then
    log_info "Running in Coder mode (packages expected in image)"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to install packages based on OS
install_package() {
    local package=$1

    case $OS in
        macos)
            if ! command_exists brew; then
                log_error "Homebrew not found. Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

                # Add Homebrew to PATH for Apple Silicon
                if [[ $(uname -m) == "arm64" ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
            fi

            if ! brew list "$package" &> /dev/null; then
                log_info "Installing $package via Homebrew..."
                brew install "$package"
            else
                log_info "$package already installed (Homebrew)"
            fi
            ;;

        ubuntu|debian)
            if ! dpkg -l | grep -q "^ii  $package "; then
                log_info "Installing $package via apt..."
                sudo apt-get install -y "$package"
            else
                log_info "$package already installed (apt)"
            fi
            ;;

        arch|manjaro)
            if ! pacman -Q "$package" &> /dev/null 2>&1; then
                log_info "Installing $package via pacman..."
                sudo pacman -S --noconfirm "$package"
            else
                log_info "$package already installed (pacman)"
            fi
            ;;

        *)
            log_error "Unsupported OS: $OS"
            log_error "Please install $package manually"
            return 1
            ;;
    esac
}

# Install core packages
install_core_packages() {
    log_info "Installing core packages..."

    # Update package manager first (if needed)
    case $OS in
        ubuntu|debian)
            log_info "Updating apt package list..."
            sudo apt-get update
            ;;
        arch|manjaro)
            log_info "Updating pacman database..."
            sudo pacman -Sy
            ;;
    esac

    # Core packages (map to OS-specific names)
    local packages=()

    case $OS in
        macos)
            packages=(git curl wget neovim tmux stow)
            ;;
        ubuntu|debian)
            packages=(git curl wget unzip neovim tmux zsh stow)
            ;;
        arch|manjaro)
            packages=(git curl wget unzip neovim tmux zsh stow)
            ;;
    esac

    for pkg in "${packages[@]}"; do
        install_package "$pkg"
    done
}

# Install Bun.sh
install_bun() {
    if command_exists bun; then
        log_info "Bun already installed: $(bun --version)"
        return 0
    fi

    log_info "Installing Bun.sh..."
    curl -fsSL https://bun.sh/install | bash

    # Source bun environment if not in PATH
    if [[ -f "$HOME/.bun/bin/bun" ]] && ! command_exists bun; then
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
    fi

    if command_exists bun; then
        log_info "Bun installed successfully: $(bun --version)"
    else
        log_warn "Bun installed but not in PATH. You may need to restart your shell."
    fi
}

# Install Bitwarden CLI
install_bitwarden_cli() {
    if command_exists bw; then
        log_info "Bitwarden CLI already installed: $(bw --version)"
        return 0
    fi

    log_info "Installing Bitwarden CLI..."

    case $OS in
        macos)
            brew install bitwarden-cli
            ;;

        ubuntu|debian|arch|manjaro)
            # Download latest version from GitHub
            log_info "Downloading Bitwarden CLI from GitHub..."

            local BW_VERSION
            BW_VERSION=$(curl -s https://api.github.com/repos/bitwarden/clients/releases/latest | grep '"tag_name":' | sed -E 's/.*"cli-v([^"]+)".*/\1/')

            if [[ -z "$BW_VERSION" ]]; then
                log_error "Failed to fetch Bitwarden CLI version"
                return 1
            fi

            log_info "Latest version: $BW_VERSION"

            local TEMP_DIR
            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"

            wget -q "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip"
            unzip -q "bw-linux-${BW_VERSION}.zip"
            sudo mv bw /usr/local/bin/
            sudo chmod +x /usr/local/bin/bw

            cd - > /dev/null
            rm -rf "$TEMP_DIR"
            ;;
    esac

    if command_exists bw; then
        log_info "Bitwarden CLI installed successfully: $(bw --version)"
    else
        log_error "Bitwarden CLI installation failed"
        return 1
    fi
}

# Install LazyVim
install_lazyvim() {
    if [[ -d "$HOME/.config/nvim" ]]; then
        log_info "Neovim config already exists at ~/.config/nvim"
        log_warn "Skipping LazyVim installation (remove ~/.config/nvim to reinstall)"
        return 0
    fi

    log_info "Installing LazyVim starter configuration..."
    git clone https://github.com/LazyVim/starter ~/.config/nvim

    log_info "LazyVim installed. Launch 'nvim' to complete plugin setup."
}

# Link dotfiles using Stow
link_dotfiles() {
    log_info "Linking dotfiles with GNU Stow..."

    local DOTFILES_DIR
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    cd "$DOTFILES_DIR"

    # Stow config directory
    if [[ -d ".config" ]]; then
        log_info "Stowing .config directory..."
        stow -R -t ~/.config .config/ || {
            log_error "Failed to stow .config directory"
            log_info "This might be due to existing files. Use 'stow --adopt' to merge."
            return 1
        }
    else
        log_warn ".config directory not found in dotfiles"
    fi

    log_info "Dotfiles linked successfully"
}

# Main installation flow
main() {
    log_info "Starting dotfiles installation..."
    echo ""

    # Install packages (unless skipped)
    if [[ "$SKIP_PACKAGES" == false ]]; then
        install_core_packages
        install_bun
        install_bitwarden_cli
        echo ""
    else
        log_info "Skipping package installation"
        echo ""
    fi

    # Install LazyVim
    install_lazyvim
    echo ""

    # Link dotfiles
    link_dotfiles
    echo ""

    # Final message
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Dotfiles setup complete!"
    echo ""
    echo "Summary:"
    echo "  • Mode: ${CODER_MODE:+Coder}${CODER_MODE:-Local ($OS)}"
    echo "  • Dotfiles: Linked via GNU Stow"
    echo "  • Neovim: LazyVim configuration ready"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your shell or run: source ~/.zshrc"
    echo "  2. Launch Neovim to complete plugin installation: nvim"
    if ! command_exists bun 2>/dev/null; then
        echo "  3. Add Bun to PATH: source ~/.bun/bin/bun"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Run main installation
main
