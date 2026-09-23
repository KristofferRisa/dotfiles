# Dotfiles

Personal dotfiles, linked into place with GNU Stow.

**Guide and new-machine checklist:** [kristoffer.dev/dotfiles](https://kristoffer.dev/dotfiles/)

## Philosophy

Simple, focused dotfiles repository following UNIX principles:

- **One responsibility**: `install.sh` links configuration files, nothing else
- **Installing tools is separate**: `brew.sh`, or the bootstrap's `--tools` flag
- **GNU Stow**: clean symlink management
- **Version controlled**: every config change is a commit

---

## Installation

### On a new machine

```bash
curl -fsSL https://install.kristoffer.dev/dotfiles | bash
```

The bootstrap installs git and Stow if they are missing, clones this repo to `~/dotfiles` (or fast-forwards it), moves anything that would block Stow into `~/.dotfiles-backup/<timestamp>/`, and then runs `./install.sh`. Nothing is deleted.

```bash
# look first, change nothing
curl -fsSL https://install.kristoffer.dev/dotfiles | bash -s -- --dry-run

# also install zsh, tmux, neovim, lazygit, Oh My Zsh and Powerlevel10k
curl -fsSL https://install.kristoffer.dev/dotfiles | bash -s -- --tools
```

Read the script first: [kristoffer.dev/dotfiles/install.sh](https://kristoffer.dev/dotfiles/install.sh).

### By hand

```bash
git clone https://github.com/kristofferrisa/dotfiles.git ~/dotfiles
cd ~/dotfiles
./brew.sh      # optional: stow + lazygit via Homebrew
./install.sh
```

### What `install.sh` does

1. Checks that GNU Stow is installed
2. Checks for conflicts, and stops if a real file is in the way
3. Links `.config/*` into `~/.config/` and `.claude/*` into `~/.claude/`
4. Adds `export ZDOTDIR="$HOME/.config/zsh"` to `~/.zshenv`, so zsh reads its config from `~/.config/zsh/`

Run it again whenever you like; it relinks the same links.

### Prerequisites

- **GNU Stow** — required (`brew install stow` / `apt install stow` / `pacman -S stow`)
- **zsh** with [Oh My Zsh](https://ohmyz.sh/) and [Powerlevel10k](https://github.com/romkatv/powerlevel10k) — `.zshrc` sources both
- **tmux**, **neovim** (0.10+, for LazyVim), **lazygit**, **ghostty** — recommended

---

## What's Included

```
.config/
├── ghostty/       # Terminal: Catppuccin Mocha, OSC 52 clipboard
├── lazygit/       # lazygit: Nerd Font v3 icons
├── nvim/          # LazyVim with .NET, Go, Vue, Tailwind, DAP and Claude Code extras
├── opencode/      # OpenCode agents
├── tmux/          # Ctrl+a prefix, vim-style panes
└── zsh/           # Oh My Zsh + Powerlevel10k, aliases, completions
.claude/
└── settings.json  # Claude Code settings
```

---

## Usage

### Zsh Aliases

Key aliases from `.config/zsh/.zshrc`:

```bash
n         # nvim .
ll        # ls -al
o         # open the current directory (Finder / xdg-open)
gaa       # git add .
gcm       # git commit -m
gpsh      # git push
gss       # git status -s
c / cc    # claude (c skips permission prompts — sandboxes only)
oc        # opencode
dtable    # docker ps as a readable table
dstart    # docker compose up -d, then tail the logs
tmx NAME  # attach to a tmux session, or offer to create it
```

Machine-specific settings (proxies, tokens, extra `PATH` entries) go in `~/.config/zsh/.zshrc.local`. It is sourced if present and ignored by git.

### Tmux Keybindings

- **Prefix**: `Ctrl+a` (instead of `Ctrl+b`)
- **Split left/right**: `Ctrl+a |`
- **Split top/bottom**: `Ctrl+a -`
- **Navigate panes**: `Ctrl+a h/j/k/l`
- **Resize panes**: `Ctrl+a H/J/K/L` (Shift, repeatable)
- **Copy mode**: `Ctrl+a [` (vi keys)
- **Reload config**: `Ctrl+a r`

### Neovim

Launch `nvim`. The first launch installs every plugin — give it a minute.

---

## Repository Structure

```
dotfiles/
├── install.sh      # Link dotfiles with Stow, set ZDOTDIR
├── brew.sh         # Install stow + lazygit via Homebrew
├── .config/        # Linked into ~/.config/
├── .claude/        # Linked into ~/.claude/
└── README.md
```

---

## Updating Dotfiles

```bash
cd ~/dotfiles
git pull
./install.sh  # Re-link configs
```

Or re-run the one-liner, which does both.

---

## Modifying Configurations

Since configs are symlinked, you can edit them in place:

```bash
nvim ~/.config/zsh/.zshrc
# is the same file as
nvim ~/dotfiles/.config/zsh/.zshrc

cd ~/dotfiles
git add .config/zsh/.zshrc
git commit -m "Update zsh config"
git push
```

zsh keeps its history and completion cache in `~/.config/zsh/` too, which is inside this repo. `.gitignore` keeps them out of commits.

---

## Troubleshooting

### "GNU Stow not installed"

```bash
brew install stow        # macOS
sudo apt install stow    # Ubuntu/Debian
sudo pacman -S stow      # Arch
```

### "Conflicts detected"

A real file is where a link should go. Either run the bootstrap, which moves conflicts to `~/.dotfiles-backup/`, or move the file yourself:

```bash
mv ~/.config/zsh ~/.config/zsh.backup
./install.sh
```

### Unlinking Configs

```bash
cd ~/dotfiles
stow -D -t ~/.config .config/
stow -D -t ~/.claude .claude/
```

---

## Design Principles

1. **Do one thing well**: `install.sh` links dotfiles, nothing more
2. **Minimal complexity**: one short shell script
3. **No hidden magic**: clear, readable code
4. **Fail fast**: exit on errors with helpful messages
5. **Composable**: works with your existing tools

---

## License

MIT License - Use as you wish.

---

## Resources

- [GNU Stow Manual](https://www.gnu.org/software/stow/manual/stow.html)
- [Oh-My-Zsh](https://ohmyz.sh/)
- [Neovim](https://neovim.io/)
- [Tmux](https://github.com/tmux/tmux/wiki)
