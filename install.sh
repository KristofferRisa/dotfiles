#!/bin/bash
set -euo pipefail

# install.sh - Link dotfiles using GNU Stow
#
# Purpose: Create symlinks from .config/* to ~/.config/
#
# Prerequisites:
#   - GNU Stow installed
#   - Backup any conflicting files in ~/.config/

# ────────────────────────────────────────────────────────────
# Colors for output
# ────────────────────────────────────────────────────────────

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

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ────────────────────────────────────────────────────────────
# Prerequisite checks
# ────────────────────────────────────────────────────────────

check_stow() {
    if ! command -v stow &>/dev/null; then
        log_error "GNU Stow is not installed"
        echo ""
        echo "Install it first:"
        echo "  macOS:    brew install stow"
        echo "  Ubuntu:   sudo apt-get install stow"
        echo "  Arch:     sudo pacman -S stow"
        return 1
    fi
    return 0
}

# ────────────────────────────────────────────────────────────
# Dotfiles linking
# ────────────────────────────────────────────────────────────

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
        log_error ".config directory not found in dotfiles"
        return 1
    fi

    log_info "Checking for conflicts..."

    # Check for conflicts first (dry-run)
    if ! stow -n -t ~/.config .config/ 2>/dev/null; then
        log_error "Stow conflict detected. Existing files would be overwritten:"
        echo ""
        stow -n -t ~/.config .config/ 2>&1 || true
        echo ""
        log_info "Solutions:"
        log_info "  1. Backup existing files and retry"
        log_info "  2. Use 'stow --adopt' to merge (WARNING: overwrites dotfiles repo)"
        log_info "  3. Manually resolve conflicts"
        return 1
    fi

    # Perform the stow operation
    log_info "Creating symlinks..."
    if ! stow -R -t ~/.config .config/; then
        log_error "Failed to stow .config directory"
        return 1
    fi

    log_info "Dotfiles linked successfully"
    return 0
}

list_linked_configs() {
    echo ""
    echo "Linked configurations:"
    find .config -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort | sed 's/^/  • /'
    echo ""
}

# ────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Dotfiles Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Check prerequisites
    if ! check_stow; then
        exit 1
    fi

    # Link dotfiles
    if ! link_dotfiles; then
        exit 1
    fi

    # Show what was linked
    list_linked_configs

    # Success message
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "Setup complete!"
    echo ""
    echo "Next steps:"
    echo "  • Restart your shell or run: source ~/.zshrc"
    echo "  • Launch applications to verify configurations"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

main "$@"
