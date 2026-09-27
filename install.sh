#!/bin/bash
# Install dotfiles.
#
#   curl -fsSL https://kristoffer.dev/dotfiles/install | bash
#   curl -fsSL https://kristoffer.dev/dotfiles/install | bash -s -- --dry-run
#   ./install.sh [--dry-run] [--link-only] [--update]
#
# A piped shell is still reading this script from stdin, so the first run
# only clones the repo and re-execs the on-disk copy. The on-disk copy is
# what installs dependencies and creates the symlinks.
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/KristofferRisa/dotfiles.git}"
DEST="${DOTFILES_DEST:-$HOME/dotfiles}"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

# Stow is required. The rest are the tools this repo configures.
BREW_PACKAGES=(stow jq lazygit tmux neovim)
# Distro neovim is usually older than LazyVim supports, so Linux skips it.
LINUX_PACKAGES=(git stow zsh tmux jq)

DRY_RUN=0
LINK_ONLY=0
UPDATE=0

usage() {
  cat <<'EOF'
Usage: install.sh [--dry-run] [--link-only] [--update]

Installs what this repo's configs need, then links them with GNU Stow.

  --dry-run     Show what would be installed, linked, and moved. Change nothing.
  --link-only   Skip package, Oh My Zsh, and Powerlevel10k installs. Only link.
  --update      Pull the latest changes into this checkout first, then install
                and link as usual. Run this from ~/dotfiles instead of a manual
                `git pull && ./install.sh`.
  -h, --help    Show this help.

Files that block a link are moved to ~/.dotfiles-backup/<timestamp>/.
Nothing is deleted.

Environment:
  DOTFILES_REPO   Repo to clone when piped (default: GitHub)
  DOTFILES_DEST   Where to clone it (default: ~/dotfiles)
EOF
}

log() {
  printf '%s\n' "$*"
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

# Print a command in dry-run mode, run it otherwise.
run() {
  if ((DRY_RUN)); then
    log "  would run: $*"
  else
    "$@"
  fi
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --link-only) LINK_ONLY=1 ;;
      --update) UPDATE=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) die "Unknown option: $1 (see --help)" ;;
    esac
    shift
  done
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

  if ((DRY_RUN)); then
    log "  would install Homebrew"
    return 1
  fi

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

  if ! ensure_homebrew; then
    # Dry run without Homebrew: everything would be installed.
    log "  would run: brew install ${BREW_PACKAGES[*]}"
    return 0
  fi

  for pkg in "${BREW_PACKAGES[@]}"; do
    if ! brew list --formula "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  command -v zsh >/dev/null 2>&1 || missing+=(zsh)
  command -v git >/dev/null 2>&1 || missing+=(git)

  if ((${#missing[@]} > 0)); then
    log "Installing: ${missing[*]}"
    run brew install "${missing[@]}"
  else
    log "Homebrew packages already installed: ${BREW_PACKAGES[*]}"
  fi
}

install_linux_packages() {
  local pkg
  local missing=()

  for pkg in "${LINUX_PACKAGES[@]}"; do
    command -v "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done

  if ((${#missing[@]} == 0)); then
    log "Already installed: ${LINUX_PACKAGES[*]}"
    return 0
  fi

  log "Installing: ${missing[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    run sudo apt-get update
    run sudo apt-get install -y "${missing[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    run sudo pacman -S --needed --noconfirm "${missing[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    run sudo dnf install -y "${missing[@]}"
  else
    die "Install these packages with your package manager, then re-run: ${missing[*]}"
  fi
}

install_packages() {
  case "$(uname -s)" in
    Darwin) install_brew_packages ;;
    Linux) install_linux_packages ;;
  esac
}

require_tools() {
  local tool
  for tool in git stow zsh; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is not installed. Install it, or run without --link-only."
  done
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
    if ((DRY_RUN)); then
      log "  would run the Oh My Zsh installer (--unattended --keep-zshrc)"
    else
      ZSH="$HOME/.oh-my-zsh" ZDOTDIR='' \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    fi
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
    run mkdir -p "$(dirname "$theme_dir")"
    run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
  else
    log "Powerlevel10k already installed"
  fi
}

# Stow names each blocked path relative to the target directory. Stow 2.4
# says "... over existing target X since ...", older releases end the line
# with ": X".
stow_conflicts() {
  sed -n \
    -e 's/.*over existing target \(.*\) since .*/\1/p' \
    -e 's/.*existing target is [^:]*: \(.*\)$/\1/p'
}

# Move everything that blocks a link into BACKUP_DIR, keeping its path
# relative to $HOME so it is obvious where each file came from.
back_up_conflicts() {
  local target="$1"
  local conflicts="$2"
  local rel src dest

  while IFS= read -r rel; do
    [[ -n "$rel" ]] || continue
    src="$target/$rel"
    dest="$BACKUP_DIR/${src#"$HOME"/}"

    if ((DRY_RUN)); then
      log "  would move $src -> $dest"
    else
      mkdir -p "$(dirname "$dest")"
      mv "$src" "$dest"
      log "  moved $src -> $dest"
    fi
  done <<<"$conflicts"
}

stow_package() {
  local package="$1"
  local target="$2"
  local preview conflicts

  if [[ ! -d "$DOTFILES_DIR/$package" ]]; then
    return 0
  fi

  log "Linking $package -> $target"
  if [[ ! -d "$target" ]]; then
    run mkdir -p "$target"
    # A dry run cannot preview a target that does not exist yet, and
    # nothing can conflict inside it.
    [[ -d "$target" ]] || return 0
  fi

  # Dry-run first, so every blocking file is known before anything moves.
  if ! preview="$(stow -n -t "$target" -d "$DOTFILES_DIR" "$package" 2>&1)"; then
    conflicts="$(printf '%s\n' "$preview" | stow_conflicts)"
    if [[ -z "$conflicts" ]]; then
      printf '%s\n' "$preview" | grep -v 'simulation mode' >&2 || true
      die "Stow could not link $package into $target."
    fi
    back_up_conflicts "$target" "$conflicts"
  fi

  run stow -R -t "$target" -d "$DOTFILES_DIR" "$package"
}

# ~/.zshenv is read before ZDOTDIR takes effect. .zshrc puts Homebrew on
# PATH itself, so ZDOTDIR is all this file needs.
setup_zshenv() {
  local zshenv="$HOME/.zshenv"
  # Written literally: $HOME expands when zsh reads the file.
  # shellcheck disable=SC2016
  local line='export ZDOTDIR="$HOME/.config/zsh"'

  if [[ -f "$zshenv" ]] && grep -q 'ZDOTDIR' "$zshenv"; then
    log "ZDOTDIR already set in $zshenv"
  elif ((DRY_RUN)); then
    log "  would add to $zshenv: $line"
  else
    printf '%s\n' "$line" >>"$zshenv"
    log "Added ZDOTDIR to $zshenv"
  fi
}

# .config/git/config signs every commit with this key, so without it every
# commit fails. Generating or uploading a key is the user's call; say how.
check_signing_key() {
  local key="$HOME/.ssh/id_ed25519.pub"

  if [[ -f "$key" ]]; then
    log "Commit signing key found: $key"
    return 0
  fi

  cat <<EOF

Note: git signs commits with $key, which does not exist yet.
Commits will fail until you create it and add it to GitHub:

  ssh-keygen -t ed25519 -C "\$(git config user.email)"
  gh auth refresh -h github.com -s admin:ssh_signing_key
  gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "\$(hostname -s)"
  gh ssh-key add ~/.ssh/id_ed25519.pub --type authentication --title "\$(hostname -s)"

Then add the key to ~/.config/git/allowed_signers, or use another key via
~/.config/git/config.local. See README.md, "Signed commits".

EOF
}

bootstrap() {
  local dest="$DEST"

  if ((DRY_RUN)); then
    # Look without touching ~/dotfiles: clone to a throwaway directory.
    command -v git >/dev/null 2>&1 || die "A dry run needs git to fetch the repo. Install git, or run without --dry-run."
    dest="$(mktemp -d)/dotfiles"
    log "Dry run: cloning $REPO_URL into $dest"
    git clone --quiet --depth=1 "$REPO_URL" "$dest"
  else
    ((LINK_ONLY)) || install_packages
    command -v git >/dev/null 2>&1 || die "Install git, then re-run this script."

    if [[ -d "$dest/.git" ]]; then
      log "Updating $dest"
      git -C "$dest" pull --ff-only
    elif [[ -e "$dest" ]]; then
      die "$dest already exists and is not a git checkout. Move it or set DOTFILES_DEST."
    else
      log "Cloning $REPO_URL into $dest"
      git clone "$REPO_URL" "$dest"
    fi
  fi

  exec bash "$dest/install.sh" "$@" </dev/null
}

# `--update` from a checkout is `git pull && ./install.sh` in one step. Re-exec
# afterward for the same reason bootstrap() does: this file may have just
# changed underneath the running interpreter, and a fresh process reading it
# off disk avoids acting on a half-old, half-new copy.
update_checkout() {
  [[ -d "$DOTFILES_DIR/.git" ]] || die "$DOTFILES_DIR is not a git checkout, so --update has nothing to pull."

  if ((DRY_RUN)); then
    log "  would run: git -C $DOTFILES_DIR pull --ff-only"
    return 0
  fi

  log "Updating $DOTFILES_DIR"
  git -C "$DOTFILES_DIR" pull --ff-only

  # Bash 3.2 (macOS's system bash) treats "${arr[@]}" as unbound under -u when
  # arr is empty, so only splice it in when --link-only actually set it.
  if ((LINK_ONLY)); then
    exec bash "$DOTFILES_DIR/install.sh" --link-only
  else
    exec bash "$DOTFILES_DIR/install.sh"
  fi
}

main() {
  parse_args "$@"

  if ! running_from_checkout; then
    bootstrap "$@"
  fi

  DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ((DRY_RUN)) && log "Dry run: nothing will be changed."

  ((UPDATE)) && update_checkout

  if ((LINK_ONLY)); then
    require_tools
  else
    install_packages
    install_shell_framework
  fi

  if ! command -v stow >/dev/null 2>&1; then
    ((DRY_RUN)) || die "GNU Stow is still not available."
    log "Stow is not installed yet, so the link preview is skipped."
  else
    stow_package .config "$HOME/.config"
    stow_package .claude "$HOME/.claude"
  fi
  setup_zshenv
  check_signing_key

  if ((DRY_RUN)); then
    log "Dry run done. Run again without --dry-run to apply."
    return 0
  fi

  log "Done. Dotfiles are linked from $DOTFILES_DIR"
  [[ -d "$BACKUP_DIR" ]] && log "Files that were in the way are in $BACKUP_DIR"
  log "Open a new terminal so zsh reads ~/.config/zsh."
}

main "$@"
