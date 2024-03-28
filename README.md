# Dotfiles Repository

This repository contains personal system dotfiles for easy synchronization and setup of a new machine or environment.

## Installation / Usage

To install and use these dotfiles, open your terminal and execute the following command:

```sh
REPO_URL="https://github.com/kristofferrisa/dotfiles" && TMP_DIR=$(mktemp -d) && git clone "$REPO_URL" "$TMP_DIR" && rsync -avh --no-perms --exclude="LICENSE" --exclude=".gitignore" --exclude="README.md" --exclude=".git" "$TMP_DIR/" ~/ && echo "Sync initiated on: $(date)" >> ~/dotfiles_sync.log && rm -rf "$TMP_DIR"
