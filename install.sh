#!/bin/bash
set -euo pipefail

# Colors for output (using tput for better portability)
if command -v tput &>/dev/null && [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    NC=$(tput sgr0)
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Installation tracking
declare -a INSTALLED_PACKAGES=()
declare -a FAILED_PACKAGES=()

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

# Function to check privileges
check_privileges() {
    if [[ "$SKIP_PACKAGES" == false ]] && [[ "$OS" != "macos" ]]; then
        if ! sudo -n true 2>/dev/null; then
            log_warn "This script requires sudo privileges for package installation"
            log_info "You may be prompted for your password"

            if ! sudo -v; then
                log_error "Failed to obtain sudo privileges"
                return 1
            fi
        fi
    fi
    return 0
}

# Function to install Homebrew if needed
install_homebrew() {
    if command_exists brew; then
        return 0
    fi

    log_info "Homebrew not found. Installing Homebrew..."

    local BREW_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    local TEMP_FILE
    TEMP_FILE=$(mktemp) || {
        log_error "Failed to create temporary file"
        return 1
    }

    # Ensure cleanup
    trap "rm -f '$TEMP_FILE'" EXIT ERR

    # Download with explicit timeout and retry limits
    if ! curl -fsSL --max-time 30 --retry 3 "$BREW_URL" -o "$TEMP_FILE"; then
        log_error "Failed to download Homebrew installer"
        rm -f "$TEMP_FILE"
        trap - EXIT ERR
        return 1
    fi

    # Verify downloaded file is not empty and is a shell script
    if [[ ! -s "$TEMP_FILE" ]]; then
        log_error "Downloaded installer is empty"
        rm -f "$TEMP_FILE"
        trap - EXIT ERR
        return 1
    fi

    if ! head -1 "$TEMP_FILE" | grep -q "^#!/"; then
        log_error "Downloaded file does not appear to be a shell script"
        rm -f "$TEMP_FILE"
        trap - EXIT ERR
        return 1
    fi

    # Execute with bounded timeout (5 minutes)
    if ! timeout 300 /bin/bash "$TEMP_FILE"; then
        log_error "Homebrew installation failed or timed out"
        rm -f "$TEMP_FILE"
        trap - EXIT ERR
        return 1
    fi

    # Cleanup
    rm -f "$TEMP_FILE"
    trap - EXIT ERR

    # Add Homebrew to PATH for Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if command_exists brew; then
        log_info "Homebrew installed successfully"
        return 0
    else
        log_error "Homebrew installation completed but command not found"
        return 1
    fi
}

# Function to install packages based on OS
install_package() {
    local package=$1
    local verify_cmd="${2:-$package}"

    case $OS in
        macos)
            if ! install_homebrew; then
                FAILED_PACKAGES+=("$package")
                return 1
            fi

            if ! brew list "$package" &> /dev/null; then
                log_info "Installing $package via Homebrew..."
                if ! brew install "$package"; then
                    log_error "Failed to install $package"
                    FAILED_PACKAGES+=("$package")
                    return 1
                fi
            else
                log_info "$package already installed (Homebrew)"
            fi
            ;;

        ubuntu|debian)
            if ! dpkg -l | grep -q "^ii  $package "; then
                log_info "Installing $package via apt..."
                if ! sudo apt-get install -y "$package"; then
                    log_error "Failed to install $package"
                    FAILED_PACKAGES+=("$package")
                    return 1
                fi
            else
                log_info "$package already installed (apt)"
            fi
            ;;

        arch|manjaro)
            if ! pacman -Q "$package" &> /dev/null 2>&1; then
                log_info "Installing $package via pacman..."
                if ! sudo pacman -S --noconfirm "$package"; then
                    log_error "Failed to install $package"
                    FAILED_PACKAGES+=("$package")
                    return 1
                fi
            else
                log_info "$package already installed (pacman)"
            fi
            ;;

        *)
            log_error "Unsupported OS: $OS"
            log_error "Please install $package manually"
            FAILED_PACKAGES+=("$package")
            return 1
            ;;
    esac

    # Verify installation was successful
    if ! command_exists "$verify_cmd"; then
        log_error "Package $package installed but command $verify_cmd not found in PATH"
        log_error "You may need to restart your shell or update your PATH"
        FAILED_PACKAGES+=("$package")
        return 1
    fi

    log_info "$package verified successfully"
    INSTALLED_PACKAGES+=("$package")
    return 0
}

# Update package manager
update_package_manager() {
    local os=$1

    case $os in
        ubuntu|debian)
            log_info "Updating apt package list..."
            if ! sudo apt-get update; then
                log_error "Failed to update apt package list"
                return 1
            fi
            ;;
        arch|manjaro)
            log_info "Updating pacman database..."
            if ! sudo pacman -Sy; then
                log_error "Failed to update pacman database"
                return 1
            fi
            ;;
        macos)
            log_info "Package manager update not required for Homebrew"
            ;;
    esac

    return 0
}

# Get list of core packages for OS
get_core_packages() {
    local os=$1

    case $os in
        macos)
            echo "git curl wget neovim tmux stow"
            ;;
        ubuntu|debian|arch|manjaro)
            echo "git curl wget unzip neovim tmux zsh stow"
            ;;
        *)
            log_error "Unsupported OS: $os"
            return 1
            ;;
    esac
}

# Install core packages
install_core_packages() {
    log_info "Installing core packages..."

    # Update package manager
    if ! update_package_manager "$OS"; then
        log_error "Failed to update package manager"
        return 1
    fi

    # Get package list for this OS
    local packages
    if ! packages=$(get_core_packages "$OS"); then
        log_error "Failed to determine package list"
        return 1
    fi

    # Install each package
    local failed=0
    for pkg in $packages; do
        if ! install_package "$pkg"; then
            log_error "Failed to install $pkg"
            ((failed++))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "$failed package(s) failed to install"
        return 1
    fi

    log_info "All core packages installed successfully"
    return 0
}

# Install Bun.sh
install_bun() {
    if command_exists bun; then
        local version
        version=$(bun --version 2>/dev/null || echo "unknown")
        log_info "Bun already installed: $version"
        return 0
    fi

    log_info "Installing Bun.sh..."

    local MAX_INSTALL_TIME=300  # 5 minutes max
    local BUN_INSTALL_URL="https://bun.sh/install"
    local TEMP_INSTALLER
    TEMP_INSTALLER=$(mktemp) || {
        log_error "Failed to create temporary file"
        return 1
    }

    # Ensure cleanup
    trap "rm -f '$TEMP_INSTALLER'" EXIT ERR

    # Download installer with timeout and retry
    if ! curl -fsSL --max-time 30 --retry 3 "$BUN_INSTALL_URL" -o "$TEMP_INSTALLER"; then
        log_error "Failed to download Bun installer"
        rm -f "$TEMP_INSTALLER"
        trap - EXIT ERR
        return 1
    fi

    # Verify downloaded file is not empty and is a shell script
    if [[ ! -s "$TEMP_INSTALLER" ]]; then
        log_error "Downloaded installer is empty"
        rm -f "$TEMP_INSTALLER"
        trap - EXIT ERR
        return 1
    fi

    if ! head -1 "$TEMP_INSTALLER" | grep -q "^#!/"; then
        log_error "Downloaded file does not appear to be a shell script"
        rm -f "$TEMP_INSTALLER"
        trap - EXIT ERR
        return 1
    fi

    # Execute with timeout
    if ! timeout "$MAX_INSTALL_TIME" bash "$TEMP_INSTALLER"; then
        log_error "Bun installation failed or timed out after ${MAX_INSTALL_TIME}s"
        rm -f "$TEMP_INSTALLER"
        trap - EXIT ERR
        return 1
    fi

    # Cleanup installer
    rm -f "$TEMP_INSTALLER"
    trap - EXIT ERR

    # Add to PATH if needed
    if [[ -f "$HOME/.bun/bin/bun" ]] && ! command_exists bun; then
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
    fi

    # Verify installation
    if command_exists bun; then
        local version
        version=$(bun --version 2>/dev/null || echo "unknown")
        log_info "Bun installed successfully: $version"
        return 0
    else
        log_error "Bun installation completed but command not found in PATH"
        log_warn "You may need to restart your shell or add to PATH manually"
        return 1
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
            if ! brew install bitwarden-cli; then
                log_error "Failed to install Bitwarden CLI via Homebrew"
                return 1
            fi
            ;;

        ubuntu|debian|arch|manjaro)
            local API_URL="https://api.github.com/repos/bitwarden/clients/releases/latest"
            local TEMP_JSON
            TEMP_JSON=$(mktemp) || {
                log_error "Failed to create temp file"
                return 1
            }

            # Download with timeout and retry
            if ! curl -fsSL --max-time 30 --retry 3 "$API_URL" -o "$TEMP_JSON"; then
                log_error "Failed to fetch Bitwarden release info"
                rm -f "$TEMP_JSON"
                return 1
            fi

            # Parse version (with fallback if jq not available)
            local BW_VERSION
            if command_exists jq; then
                BW_VERSION=$(jq -r '.tag_name' "$TEMP_JSON" | sed 's/^cli-v//')
            else
                log_warn "jq not found, using fallback parsing (less safe)"
                BW_VERSION=$(grep -o '"tag_name":[[:space:]]*"cli-v[^"]*"' "$TEMP_JSON" | head -1 | sed -E 's/.*"cli-v([^"]+)".*/\1/')
            fi

            rm -f "$TEMP_JSON"

            # Validate version format (semantic versioning)
            if ! [[ "$BW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                log_error "Invalid version format: $BW_VERSION"
                return 1
            fi

            log_info "Latest version: $BW_VERSION"

            local TEMP_DIR
            TEMP_DIR=$(mktemp -d) || {
                log_error "Failed to create temp directory"
                return 1
            }

            # Ensure cleanup on error
            trap "rm -rf '$TEMP_DIR'" EXIT ERR

            local DOWNLOAD_URL="https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip"

            # Download with verification
            if ! wget -q --timeout=30 --tries=3 "$DOWNLOAD_URL" -O "$TEMP_DIR/bw.zip"; then
                log_error "Failed to download Bitwarden CLI"
                rm -rf "$TEMP_DIR"
                trap - EXIT ERR
                return 1
            fi

            # Verify zip integrity
            if ! unzip -t "$TEMP_DIR/bw.zip" &>/dev/null; then
                log_error "Downloaded zip file is corrupted"
                rm -rf "$TEMP_DIR"
                trap - EXIT ERR
                return 1
            fi

            if ! unzip -q "$TEMP_DIR/bw.zip" -d "$TEMP_DIR"; then
                log_error "Failed to extract Bitwarden CLI"
                rm -rf "$TEMP_DIR"
                trap - EXIT ERR
                return 1
            fi

            # Verify binary is executable and not empty
            if [[ ! -f "$TEMP_DIR/bw" ]] || [[ ! -s "$TEMP_DIR/bw" ]]; then
                log_error "Extracted binary is invalid"
                rm -rf "$TEMP_DIR"
                trap - EXIT ERR
                return 1
            fi

            # Install with proper permissions
            if ! sudo install -m 0755 -o root -g root "$TEMP_DIR/bw" /usr/local/bin/bw; then
                log_error "Failed to install binary to /usr/local/bin"
                rm -rf "$TEMP_DIR"
                trap - EXIT ERR
                return 1
            fi

            # Cleanup
            rm -rf "$TEMP_DIR"
            trap - EXIT ERR
            ;;
    esac

    # Final verification
    if command_exists bw; then
        log_info "Bitwarden CLI installed successfully: $(bw --version)"
        return 0
    else
        log_error "Bitwarden CLI installation failed"
        return 1
    fi
}

# Install LazyVim
install_lazyvim() {
    local NVIM_CONFIG="$HOME/.config/nvim"

    if [[ -d "$NVIM_CONFIG" ]]; then
        # Check if it's actually LazyVim
        if [[ -f "$NVIM_CONFIG/lazy-lock.json" ]] || grep -q "LazyVim" "$NVIM_CONFIG/init.lua" 2>/dev/null; then
            log_info "LazyVim already installed at $NVIM_CONFIG"
            return 0
        else
            log_warn "Neovim config exists at $NVIM_CONFIG but is not LazyVim"
            log_warn "To install LazyVim, backup and remove: $NVIM_CONFIG"
            return 1
        fi
    fi

    log_info "Installing LazyVim starter configuration..."

    if ! git clone --depth 1 https://github.com/LazyVim/starter "$NVIM_CONFIG"; then
        log_error "Failed to clone LazyVim starter"
        return 1
    fi

    # Remove .git directory to allow user customization
    if [[ -d "$NVIM_CONFIG/.git" ]]; then
        rm -rf "$NVIM_CONFIG/.git"
        log_info "Removed .git directory for customization"
    fi

    log_info "LazyVim installed. Launch 'nvim' to complete plugin setup."
    return 0
}

# Link dotfiles using Stow
link_dotfiles() {
    log_info "Linking dotfiles with GNU Stow..."

    local DOTFILES_DIR
    DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || {
        log_error "Failed to determine dotfiles directory"
        return 1
    }

    if ! cd "$DOTFILES_DIR"; then
        log_error "Failed to change to dotfiles directory: $DOTFILES_DIR"
        return 1
    fi

    if [[ ! -d ".config" ]]; then
        log_warn ".config directory not found in dotfiles"
        return 1
    fi

    log_info "Stowing .config directory..."

    # First check for conflicts
    if ! stow -n -t ~/.config .config/ 2>/dev/null; then
        log_error "Stow conflict detected. Existing files would be overwritten:"
        stow -n -t ~/.config .config/ 2>&1 || true
        log_info "Solutions:"
        log_info "  1. Backup existing files and retry"
        log_info "  2. Use 'stow --adopt' to merge (WARNING: overwrites dotfiles repo)"
        log_info "  3. Manually resolve conflicts"
        return 1
    fi

    # Actually perform the stow operation
    if ! stow -R -t ~/.config .config/; then
        log_error "Failed to stow .config directory"
        return 1
    fi

    log_info "Dotfiles linked successfully"
    return 0
}

# Print installation summary
print_installation_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Installation Summary"
    echo ""

    if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
        echo "Successfully installed (${#INSTALLED_PACKAGES[@]}):"
        printf '  ✓ %s\n' "${INSTALLED_PACKAGES[@]}"
    fi

    if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
        echo ""
        echo "Failed installations (${#FAILED_PACKAGES[@]}):"
        printf '  ✗ %s\n' "${FAILED_PACKAGES[@]}"
        echo ""
        log_warn "Some packages failed to install. Review errors above."
        return 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    return 0
}

# Main installation flow
main() {
    log_info "Starting dotfiles installation..."
    echo ""

    # Check privileges if needed
    if ! check_privileges; then
        log_error "Cannot proceed without required privileges"
        exit 1
    fi

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

    # Print summary if packages were installed
    if [[ "$SKIP_PACKAGES" == false ]]; then
        print_installation_summary
        echo ""
    fi

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
