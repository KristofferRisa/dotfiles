#!/bin/bash
set -e

echo "Installing dependencies..."
sudo apt update
sudo apt install -y git curl wget unzip neovim

# Clone the dotfiles repository (if not already present)
if [ ! -d "$HOME/dotfiles" ]; then
  git clone --recurse-submodules https://github.com/kristofferrisa/dotfiles.git ~/dotfiles
fi

# Navigate to the dotfiles directory
cd ~/dotfiles

# Remove the old custom Neovim configuration (if any)
rm -rf ~/.config/nvim

# Clone LazyVim's starter configuration into ~/.config/nvim
echo "Installing LazyVim configuration..."
git clone https://github.com/LazyVim/starter ~/.config/nvim

# If you have custom LazyVim overrides, you can symlink them in.
# For example, if you moved your overrides to dotfiles/nvim-custom:
# rm -rf ~/.config/nvim/lua/custom
# ln -s ~/dotfiles/nvim-custom ~/.config/nvim/lua/custom

# Stow other configurations
# stow -R -t ~/.local/bin bin
stow -t ~/.config .config/

echo "Dotfiles and LazyVim setup complete. Launch Neovim to finish the plugin setup."
