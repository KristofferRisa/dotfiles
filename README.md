# Dotfiles

[![CI](https://github.com/KristofferRisa/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/KristofferRisa/dotfiles/actions/workflows/ci.yml)

Personal config for zsh, tmux, neovim, ghostty, and a few other tools. [GNU Stow](https://www.gnu.org/software/stow/) symlinks this repo into your home directory, so editing a file here edits the live config.

## Install

```bash
curl -fsSL https://install.kristoffer.dev/dotfiles | bash
```

Until that hostname is live, the same script runs from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/KristofferRisa/dotfiles/main/install.sh | bash
```

Look first, change nothing:

```bash
curl -fsSL https://raw.githubusercontent.com/KristofferRisa/dotfiles/main/install.sh | bash -s -- --dry-run
```

Both commands clone this repo to `~/dotfiles` and run `install.sh`. The script:

1. Installs what the configs need. On macOS: Homebrew (if missing), Stow, lazygit, tmux, and neovim. On Linux: `git`, `stow`, `zsh`, and `tmux` with apt, pacman, or dnf.
2. Installs Oh My Zsh and Powerlevel10k when they are not already there.
3. Links `.config` into `~/.config` and `.claude` into `~/.claude`. Anything already in the way is moved to `~/.dotfiles-backup/<timestamp>/`. Nothing is deleted.
4. Adds `export ZDOTDIR="$HOME/.config/zsh"` to `~/.zshenv`, so zsh reads its config from this repo.

Open a new terminal when it finishes. Run it again whenever you like; a second run changes nothing.

| Flag | Effect |
| --- | --- |
| `--dry-run` | Print what would be installed, linked, and moved |
| `--link-only` | Skip installs, only link (needs git, stow, and zsh already) |

From a checkout: `./install.sh`. Clone somewhere else with `DOTFILES_DEST=/path/to/dotfiles`.

Not installed for you: Ghostty (`brew install --cask ghostty`), and neovim on Linux, where distro packages are usually older than LazyVim supports.

## Update

```bash
cd ~/dotfiles
git pull
./install.sh
```

Or re-run the one-liner, which does both.

## What's included

```
.config/
├── ghostty/     # Terminal: Catppuccin Mocha, OSC 52 clipboard
├── lazygit/     # lazygit: Nerd Font v3 icons
├── nvim/        # LazyVim with .NET, Go, Vue, Tailwind, DAP and Claude Code extras
├── opencode/    # OpenCode agents
├── tmux/        # Ctrl+a prefix, vim-style panes
└── zsh/         # Oh My Zsh + Powerlevel10k, aliases, completions
.claude/
└── settings.json  # Claude Code settings
```

The first `nvim` launch installs every plugin. Give it a minute.

## Daily commands

Zsh aliases:

| Alias | Action |
| --- | --- |
| `n` | `nvim .` |
| `ll` | `ls -al` |
| `o` | Open the current directory (Finder / `xdg-open`) |
| `gaa` | `git add .` |
| `gcm` | `git commit -m` |
| `gpsh` | `git push` |
| `gss` | `git status -s` |
| `cc` | `claude` |
| `oc` | `opencode` |
| `dtable` | `docker ps` as a readable table |
| `dstart` | `docker compose up -d`, then tail the logs |
| `tmx NAME` | Attach to a tmux session, or offer to create it |

Machine-specific settings (proxies, tokens, extra `PATH` entries) go in `~/.config/zsh/.zshrc.local`. It is sourced if present and ignored by git.

Tmux, prefix `Ctrl+a`:

| Keys | Action |
| --- | --- |
| `\|` | Split left/right |
| `-` | Split top/bottom |
| `h` `j` `k` `l` | Move between panes |
| `H` `J` `K` `L` | Resize panes (repeatable) |
| `[` | Copy mode (vi keys) |
| `r` | Reload config |

## Edit

The files in `~/.config` are symlinks. This edits the repo copy:

```bash
nvim ~/.config/zsh/.zshrc
```

Commit from `~/dotfiles`. zsh keeps its history and completion cache in `~/.config/zsh/` too, which is inside this repo; `.gitignore` keeps them out of commits.

See [CONTRIBUTING.md](CONTRIBUTING.md) for how changes are tested and reviewed.

## Troubleshooting

**A file I had before is gone.** It is in `~/.dotfiles-backup/<timestamp>/`, at the same path relative to your home directory.

**Stow could not link a package.** The script prints Stow's own message. Anything other than a file in the way (for example, a link into a different checkout) is left for you to fix.

**Homebrew installed, but it is not on PATH.** Open a new terminal and run `./install.sh` again.

## Unlink

```bash
cd ~/dotfiles
stow -D -t ~/.config .config
stow -D -t ~/.claude .claude
```

## Installer URL

`https://install.kristoffer.dev/dotfiles` should redirect to this repo's `install.sh`. `curl -fsSL` follows redirects, so a 302 to the raw GitHub file is enough:

`https://raw.githubusercontent.com/KristofferRisa/dotfiles/main/install.sh`

## License

[MIT](LICENSE)
