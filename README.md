# Dotfiles

[![CI](https://github.com/KristofferRisa/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/KristofferRisa/dotfiles/actions/workflows/ci.yml)

Personal config for zsh, tmux, neovim, ghostty, and a few other tools. [GNU Stow](https://www.gnu.org/software/stow/) symlinks this repo into your home directory, so editing a file here edits the live config.

## Install

```bash
curl -fsSL https://kristoffer.dev/dotfiles/install | bash
```

Or straight from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/KristofferRisa/dotfiles/main/install.sh | bash
```

Look first, change nothing:

```bash
curl -fsSL https://kristoffer.dev/dotfiles/install | bash -s -- --dry-run
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
| `--update` | Pull the latest changes into this checkout first, then install and link |

From a checkout: `./install.sh`. Clone somewhere else with `DOTFILES_DEST=/path/to/dotfiles`.

Not installed for you: Ghostty (`brew install --cask ghostty`), and neovim on Linux, where distro packages are usually older than LazyVim supports.

## Update

```bash
cd ~/dotfiles && ./install.sh --update
```

Same as `git pull && ./install.sh`, or re-run the one-liner, which does both.

## What's included

```
.config/
├── ghostty/     # Terminal: Catppuccin Mocha, OSC 52 clipboard
├── git/         # Global git config, SSH commit signing
├── lazygit/     # lazygit: Nerd Font v3 icons
├── nvim/        # LazyVim with .NET, Go, Vue, Tailwind, DAP and Claude Code extras
├── opencode/    # OpenCode agents
├── tmux/        # Ctrl+a prefix, vim-style panes
└── zsh/         # Oh My Zsh + Powerlevel10k, aliases, completions
.claude/
├── settings.json  # Claude Code settings
└── statusline/    # Claude Code status line (bash + jq)
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

`.zshrc` sets `CLAUDE_CODE_ENABLE_TELEMETRY=1`. The OpenTelemetry exporter and endpoint are per machine, so set them in `.zshrc.local`.

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

## Claude Code status line

`.claude/statusline/` is a status line written in bash and `jq`. It needs no Node or npm package, and it takes about 40 ms per refresh.

```
 dotfiles   main ●1   Opus 5.5 · xhigh   ▰▰▱▱▱▱▱▱ 26% 256k/1M
 session $6.84 · 112k out · +412/-87 · 1h30m │ today $7.52 · cache 98% (saved $63.15) │ 5h 42% ↻1h19m │ 7d 73% ↻3d11h
```

- **session**: Claude Code's own cost figure, fresh output tokens, lines changed, and time
- **today**: every transcript since local midnight (subagents included), priced from `pricing.json`. A `~` means a model had no known price
- **cache**: share of input served from cache, and what that saved against full input price
- **5h / 7d**: subscription rate limits and when they reset, when Claude Code reports them

`bash ~/.claude/statusline/statusline.sh --report` prints today's cost by model.

It replaces `@owloops/claude-powerline`, which priced models it didn't know by falling back to a family match. `claude-opus-5-5` matched plain `opus` and was billed at Opus 4's $15/$75 per million tokens, so a real $7.13 day showed as $38.63. Here, each model id uses the longest matching key in `pricing.json`, and an unknown model is flagged rather than guessed. When a new model launches, add its row.

## Signed commits

`.config/git/config` signs every commit and tag with `~/.ssh/id_ed25519.pub` (SSH signing). The installer warns if that key is missing, because commits fail without it.

On a new machine:

```bash
ssh-keygen -t ed25519 -C "$(git config user.email)"      # skip if the key exists
gh auth refresh -h github.com -s admin:ssh_signing_key
gh ssh-key add ~/.ssh/id_ed25519.pub --type signing --title "$(hostname -s)"
```

GitHub shows commits as **Verified** once the key is added as a *signing* key. An authentication key alone is not enough, even if it is the same key.

Add the key to `.config/git/allowed_signers` too, so `git log --show-signature` can verify it locally. To use a different key or email on one machine, put the override in `~/.config/git/config.local`; it is gitignored.

If `~/.gitconfig` exists, git reads it after `~/.config/git/config`, and its settings win. Delete it once the tracked config covers everything you need.

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

The short address is `https://kristoffer.dev/dotfiles/install`. It is a small shim served by the [kristoffer.dev](https://github.com/KristofferRisa/kristoffer.dev) site (`static/dotfiles/install`) that fetches this repo's `install.sh` and runs it with the same arguments — no DNS or redirect rule to keep working, since it deploys with the rest of that site.

`install.kristoffer.dev/dotfiles` was a Cloudflare redirect rule to the raw GitHub file. It is not part of either repo and has been unreliable, so the site address above is what's documented now. The old `kristoffer.dev/dotfiles/install.sh` (with the extension) still works too, for links made before this change.

Either way, `curl -fsSL` prints the real script first, straight from GitHub:

`https://raw.githubusercontent.com/KristofferRisa/dotfiles/main/install.sh`

## License

[MIT](LICENSE)
