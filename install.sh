#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e


# Install basic dependencies (adjust as needed)
echo "Installing dependencies..."
sudo apt update
sudo apt install -y git curl wget unzip neovim

# Install packer.nvim package manager for Neovim
PACKER_DIR="$HOME/.local/share/nvim/site/pack/packer/start/packer.nvim"
if [ ! -d "$PACKER_DIR" ]; then
    echo "Installing packer.nvim..."
    git clone --depth 1 https://github.com/wbthomason/packer.nvim "$PACKER_DIR"
fi

# Clone the dotfiles repository
git clone --recurse-submodules https://github.com/kristofferrisa/dotfiles.git ~/dotfiles

# Navigate to the dotfiles directory
cd ~/dotfiles

# Stow configurations
stow -t ~ .config/nvim
stow -t ~ .config/tmux
stow -t ~ .config/zsh
stow -t ~ bin

echo "Dotfiles and Neovim setup complete. Run ':PackerSync' in Neovim to install plugins."
