# Dotfiles

Personal config for zsh, tmux, neovim, ghostty, and a few other tools. [GNU Stow](https://www.gnu.org/software/stow/) symlinks this repo into your home directory, so editing a file here edits the live config.

## Install

```bash
curl -fsSL https://install.kristoffer.dev/dotfiles | bash
```

The same script is on GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/KristofferRisa/dotfiles/main/install.sh | bash
```

Both commands clone this repo to `~/dotfiles` and run `install.sh`. The script:

1. Installs what the setup needs. On macOS that is Homebrew (if it is missing), GNU Stow, and lazygit. On Linux it installs `git`, `stow`, and `zsh` with apt, pacman, or dnf.
2. Installs Oh My Zsh and Powerlevel10k when they are not already there.
3. Symlinks `.config` to `~/.config` and `.claude` to `~/.claude`.
4. Writes `~/.zshenv` so zsh reads `~/.config/zsh`, and puts Homebrew on `PATH`. Setting `ZDOTDIR` makes zsh skip `~/.zprofile`, which is where Homebrew normally adds itself.

From a checkout you already have:

```bash
./install.sh
```

Clone somewhere else with `DOTFILES_DEST=/path/to/dotfiles`.

Open a new terminal when it finishes.

## Update

```bash
cd ~/dotfiles
git pull
./install.sh
```

## What's included

```
.config/
├── ghostty/     # Ghostty terminal
├── lazygit/     # lazygit
├── nvim/        # Neovim (LazyVim)
├── opencode/    # OpenCode agents
├── tmux/        # tmux, prefix Ctrl+a
└── zsh/         # zsh, Oh My Zsh, Powerlevel10k
.claude/         # Claude Code settings
```

Neovim, tmux, and Ghostty are not installed for you. On macOS:

```bash
brew install neovim tmux
brew install --cask ghostty
```

The first `nvim` launch installs plugins.

## Daily commands

Zsh aliases:

| Alias | Action |
| --- | --- |
| `n` | `nvim .` |
| `gaa` | `git add .` |
| `gcm` | `git commit -m` |
| `gpsh` | `git push` |
| `gss` | `git status -s` |

Tmux, prefix `Ctrl+a`:

| Keys | Action |
| --- | --- |
| `\|` | Vertical split |
| `-` | Horizontal split |
| `h` `j` `k` `l` | Move between panes |
| `H` `J` `K` `L` | Resize panes |
| `[` | Copy mode (vim keys) |

## Conflicts

Stow will not overwrite a file that is already at the destination. If `~/.config/zsh` (or another package directory) is a real folder, the script stops and prints the path. Move that path aside and run `./install.sh` again:

```bash
mv ~/.config/zsh ~/.config/zsh.backup
./install.sh
```

Leave the rest of `~/.config` where it is. Only the names inside `.config/` in this repo are linked.

## Unlink

```bash
cd ~/dotfiles
stow -D -t ~/.config .config
stow -D -t ~/.claude .claude
```

## Edit

The files in `~/.config` are symlinks. This edits the repo copy:

```bash
nvim ~/.config/zsh/.zshrc
```

Commit from `~/dotfiles`.

## Installer URL

`https://install.kristoffer.dev/dotfiles` should return this repo's `install.sh`. `curl -fsSL` follows redirects, so a redirect to the raw GitHub file is enough:

`https://raw.githubusercontent.com/KristofferRisa/dotfiles/main/install.sh`

## License

[MIT](LICENSE)
