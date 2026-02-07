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

  if [[ -d .config ]]; then
    mkdir -p ~/.config

    echo "Checking for .config conflicts..."
    stow -n -t ~/.config .config/ 2>&1 || {
      echo "Error: Conflicts detected. Backup existing files in ~/.config/"
      return 1
    }

    echo "Linking .config dotfiles..."
    stow -R -t ~/.config .config/ || {
      echo "Error: Failed to link .config dotfiles"
      return 1
    }

    echo "Done. Dotfiles linked to ~/.config/"
  fi

  if [[ -d .claude ]]; then
    mkdir -p ~/.claude

    echo "Checking for .claude conflicts..."
    stow -n -t ~/.claude .claude/ 2>&1 || {
      echo "Error: Conflicts detected. Backup existing files in ~/.claude/"
      return 1
    }

    echo "Linking .claude config..."
    stow -R -t ~/.claude .claude/ || {
      echo "Error: Failed to link .claude config"
      return 1
    }

    echo "Done. Claude config linked to ~/.claude/"
  fi
}

setup_zshenv() {
  local zshenv="$HOME/.zshenv"
  local zdotdir_line='export ZDOTDIR="$HOME/.config/zsh"'

  if [[ -f "$zshenv" ]] && grep -q 'ZDOTDIR' "$zshenv"; then
    echo "ZDOTDIR already set in $zshenv"
    return 0
  fi

  echo "Setting ZDOTDIR in $zshenv..."
  echo "$zdotdir_line" >>"$zshenv"
  echo "Done. Zsh will now read .zshrc from ~/.config/zsh/"
}

check_stow && link_dotfiles && setup_zshenv
