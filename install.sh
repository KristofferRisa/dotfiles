#!/bin/bash
# Install dotfiles.
#
#   curl -fsSL https://install.kristoffer.dev/dotfiles | bash
#   ./install.sh
#
# A piped shell is still reading this script from stdin, so the first run
# only clones the repo and re-execs the on-disk copy. The on-disk copy is
# what installs dependencies and creates the symlinks.
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/KristofferRisa/dotfiles.git}"
DEST="${DOTFILES_DEST:-$HOME/dotfiles}"

# Folded in from brew.sh. Stow is required. lazygit matches the config in this repo.
BREW_PACKAGES=(stow lazygit)

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

running_from_checkout() {
  local src="${BASH_SOURCE[0]:-}"
  [[ -n "$src" && -f "$src" && -d "$(dirname "$src")/.config" ]]
}

add_brew_to_path() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    return 1
  fi
}

ensure_homebrew() {
  add_brew_to_path && return 0

  log "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  add_brew_to_path || die "Homebrew installed, but it is not on PATH. Open a new terminal and run ./install.sh again."
}

install_brew_packages() {
  local pkg
  local missing=()

  # A full Homebrew auto-update here is slow and fails the install when
  # GitHub rate-limits the tap update. Bottles still download on demand.
  export HOMEBREW_NO_AUTO_UPDATE=1
  export HOMEBREW_NO_ENV_HINTS=1

  ensure_homebrew

  for pkg in "${BREW_PACKAGES[@]}"; do
    if ! brew list --formula "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if ! command -v zsh >/dev/null 2>&1; then
    missing+=(zsh)
  fi
  if ! command -v git >/dev/null 2>&1; then
    missing+=(git)
  fi

  if ((${#missing[@]} > 0)); then
    log "Installing: ${missing[*]}"
    brew install "${missing[@]}"
  else
    log "Homebrew packages already installed: ${BREW_PACKAGES[*]}"
  fi
}

install_linux_packages() {
  local install=()

  command -v git >/dev/null 2>&1 || install+=(git)
  command -v stow >/dev/null 2>&1 || install+=(stow)
  command -v zsh >/dev/null 2>&1 || install+=(zsh)

  if ((${#install[@]} == 0)); then
    log "git, stow, and zsh are already installed"
    return 0
  fi

  log "Installing: ${install[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y "${install[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm "${install[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y "${install[@]}"
  else
    die "Install these packages with your package manager, then re-run: ${install[*]}"
  fi
}

ensure_dependencies() {
  case "$(uname -s)" in
    Darwin) install_brew_packages ;;
    Linux) install_linux_packages ;;
    *)
      command -v stow >/dev/null 2>&1 || die "Install GNU Stow, then re-run this script."
      command -v git >/dev/null 2>&1 || die "Install git, then re-run this script."
      command -v zsh >/dev/null 2>&1 || die "Install zsh, then re-run this script."
      ;;
  esac

  command -v stow >/dev/null 2>&1 || die "GNU Stow is still not available."
  command -v git >/dev/null 2>&1 || die "git is still not available."
  command -v zsh >/dev/null 2>&1 || die "zsh is still not available."
}

# Oh My Zsh treats ZDOTDIR as its install location and, when stdin is not a
# terminal, overwrites .zshrc. Our .zshrc is about to be a symlink into this
# repo, so the installer must keep it and must use ~/.oh-my-zsh.
install_shell_framework() {
  local had_zshrc=0
  local theme_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"

  if [[ -e "$HOME/.zshrc" ]]; then
    had_zshrc=1
  fi

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log "Installing Oh My Zsh..."
    ZSH="$HOME/.oh-my-zsh" ZDOTDIR= \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
  else
    log "Oh My Zsh already installed"
  fi

  # The template lands on ~/.zshrc only when the user did not already have one.
  # ZDOTDIR points zsh at this repo, so that template would shadow nothing and
  # just confuse the next login.
  if [[ "$had_zshrc" -eq 0 && -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    rm -f "$HOME/.zshrc"
  fi

  if [[ ! -d "$theme_dir" ]]; then
    log "Installing Powerlevel10k..."
    mkdir -p "$(dirname "$theme_dir")"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
  else
    log "Powerlevel10k already installed"
  fi
}

stow_package() {
  local package="$1"
  local target="$2"

  if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
    return 0
  fi

  local preview

  mkdir -p "$target"
  log "Linking $package -> $target"

  # Dry-run first so a conflict stops us before any symlink is written.
  # Stow's simulation warning is noise; real conflicts stay in the output.
  if ! preview="$(stow -n -t "$target" -d "$DOTFILES_DIR" "$package" 2>&1)"; then
    printf '%s\n' "$preview" | grep -v 'simulation mode' >&2 || true
    die "Conflicts linking $package into $target. Move the listed files aside and run ./install.sh again."
  fi

  stow -R -t "$target" -d "$DOTFILES_DIR" "$package"
}

# ~/.zshenv is read before ZDOTDIR takes effect. After that, zsh no longer
# reads ~/.zprofile, which is where Homebrew puts itself.
setup_zshenv() {
  local zshenv="$HOME/.zshenv"
  local brew_snippet
  brew_snippet='if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi'

  if [[ ! -f "$zshenv" ]]; then
    cat >"$zshenv" <<EOF
export ZDOTDIR="\$HOME/.config/zsh"

$brew_snippet
EOF
    log "Wrote $zshenv"
    return 0
  fi

  if ! grep -q 'ZDOTDIR' "$zshenv"; then
    printf '\nexport ZDOTDIR="$HOME/.config/zsh"\n' >>"$zshenv"
    log "Added ZDOTDIR to $zshenv"
  else
    log "ZDOTDIR already set in $zshenv"
  fi

  if ! grep -q 'homebrew/bin/brew' "$zshenv"; then
    printf '\n%s\n' "$brew_snippet" >>"$zshenv"
    log "Added Homebrew to PATH in $zshenv"
  fi
}

bootstrap() {
  case "$(uname -s)" in
    Darwin) install_brew_packages ;;
    Linux) install_linux_packages ;;
    *) command -v git >/dev/null 2>&1 || die "Install git, then re-run this script." ;;
  esac

  if [[ -d "$DEST/.git" ]]; then
    log "Updating $DEST"
    git -C "$DEST" pull --ff-only
  elif [[ -e "$DEST" ]]; then
    die "$DEST already exists and is not a git checkout. Move it or set DOTFILES_DEST."
  else
    log "Cloning $REPO_URL into $DEST"
    git clone "$REPO_URL" "$DEST"
  fi

  exec bash "$DEST/install.sh" "$@" < /dev/null
}

if ! running_from_checkout; then
  bootstrap "$@"
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ensure_dependencies
install_shell_framework
stow_package .config "$HOME/.config"
stow_package .claude "$HOME/.claude"
setup_zshenv

log "Done. Dotfiles are linked from $DOTFILES_DIR"
log "Open a new terminal so zsh reads ~/.config/zsh."
