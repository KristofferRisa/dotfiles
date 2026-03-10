#!/bin/bash
set -euo pipefail

# brew.sh - Install dependencies via Homebrew

if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew not installed"
  echo "Install: https://brew.sh"
  exit 1
fi

PACKAGES=(
  stow
  lazygit
)

echo "Installing Homebrew packages..."
for pkg in "${PACKAGES[@]}"; do
  if brew list "$pkg" &>/dev/null; then
    echo "  $pkg (already installed)"
  else
    echo "  $pkg (installing...)"
    brew install "$pkg"
  fi
done

echo "Done."
