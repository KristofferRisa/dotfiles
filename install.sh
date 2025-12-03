#!/bin/bash
set -euo pipefail

# install.sh - Link dotfiles using GNU Stow
# Prerequisites: GNU Stow installed

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_stow() {
    if ! command -v stow &>/dev/null; then
        echo "Error: GNU Stow not installed"
        echo "Install: brew install stow (macOS) | apt install stow (Ubuntu) | pacman -S stow (Arch)"
        return 1
    fi
}

link_dotfiles() {
    cd "$DOTFILES_DIR" || return 1

    [[ -d .config ]] || { echo "Error: .config directory not found"; return 1; }

    echo "Checking for conflicts..."
    stow -n -t ~/.config .config/ 2>&1 || {
        echo "Error: Conflicts detected. Backup existing files in ~/.config/"
        return 1
    }

    echo "Linking dotfiles..."
    stow -R -t ~/.config .config/ || {
        echo "Error: Failed to link dotfiles"
        return 1
    }

    echo "Done. Dotfiles linked to ~/.config/"
}

check_stow && link_dotfiles
