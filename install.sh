#!/bin/bash

# Clone the dotfiles repository
git clone --recurse-submodules https://github.com/kristofferrisa/dotfiles.git ~/dotfiles

# Navigate to the dotfiles directory
cd ~/dotfiles

# Install dependencies (e.g., stow)
if ! command -v stow &> /dev/null; then
    echo "Installing stow..."
    sudo apt-get install stow
fi

# Stow configurations
stow -t ~ .config/nvim
stow -t ~ .config/tmux
stow -t ~ .config/zsh
stow -t ~ bin

echo "Dotfiles installation complete."