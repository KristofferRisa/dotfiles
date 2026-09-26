# Contributing

These are the working rules for this repo, for people and for AI agents (Claude Code, OpenCode, the `@claude` GitHub action). [CLAUDE.md](CLAUDE.md) describes how the repo is laid out; this file says how to change it.

## The one thing to remember

Every file under `.config/` and `.claude/` is **live** on each machine that ran `install.sh`: `~/.config/zsh/.zshrc` *is* `.config/zsh/.zshrc`. Saving a broken file breaks the next shell that opens, before anything is committed. Test in a throwaway home (below) when you are unsure.

## Workflow

1. Branch from `main`. Name it after the change: `fix/tmux-resize`, `install-backups`.
2. Keep each commit to one change, with a message that says what changed on the machine and why. Wrap the body at 72 columns.
   Commits are signed. `.config/git/config` does this automatically; see README, "Signed commits".
3. Open a PR and fill in the template. CI must be green before merge.
4. Merge with a merge commit or a squash; don't force-push `main`.

## Test before you push

CI runs all of this, but it is faster to catch it locally.

| Changed | Check |
| --- | --- |
| `install.sh` | `shellcheck install.sh` and `shfmt -d -i 2 -ci install.sh` |
| `install.sh` | Run it against a fake home, twice (see below) |
| zsh files | `zsh -n <file>`, then open a new shell and read any warnings |
| `tmux.conf` | `tmux source-file ~/.config/tmux/tmux.conf` in a running session |
| nvim Lua | `stylua --check .config/nvim` |
| `.github/workflows/` | `actionlint` |

`brew install shellcheck shfmt stylua actionlint` gets all of them.

### Installer in a throwaway home

```bash
export TEST_HOME="$(mktemp -d)"
HOME="$TEST_HOME" ./install.sh --dry-run   # must change nothing
HOME="$TEST_HOME" ./install.sh             # real install into the fake home
HOME="$TEST_HOME" ./install.sh             # second run must be a no-op
HOME="$TEST_HOME" ZDOTDIR="$TEST_HOME/.config/zsh" zsh -i -c exit   # must print nothing to stderr
```

Homebrew and apt packages still install system-wide; everything else stays in `$TEST_HOME`.

## Rules for `install.sh`

- **Idempotent.** A second run changes nothing and prints no `Installing`, `moved`, or `Added` lines.
- **Never delete user files.** Anything in the way goes to `~/.dotfiles-backup/<timestamp>/`.
- **`--dry-run` changes nothing.** Every write goes through `run` or checks `DRY_RUN`.
- **Safe to pipe.** `curl … | bash` must keep working; the script re-execs itself from the clone.
- **New dependency?** Add it to `BREW_PACKAGES`, and to `LINUX_PACKAGES` if the distro package is usable.
- Bash, `set -euo pipefail`, 2-space indent, functions with `local` variables. Comments explain *why*, not what.

## Rules for configs

- **zsh:** nothing above the Powerlevel10k instant-prompt block, and nothing that prints or prompts during startup. Machine-specific values (tokens, proxies, work paths) go in `.config/zsh/.zshrc.local`, which is gitignored.
- **No hardcoded home paths.** Use `$HOME` or `~`, and detect Homebrew's prefix instead of assuming `/opt/homebrew`.
- **No safety bypasses** in aliases or settings, such as `--dangerously-skip-permissions`.
- **Keep docs in step.** A new alias, keybinding, or installer step goes in README.md and CLAUDE.md in the same PR.
- **Secrets never land here.** zsh history and `.zcompdump` are written inside this repo; they are gitignored and CI runs gitleaks. Don't weaken either.

## For AI agents

- Read CLAUDE.md, then this file, before editing.
- Don't run `./install.sh` against the real `$HOME` unless the user asked for it. Use a throwaway home.
- Don't commit, push, or open PRs unless asked. When you do, follow the workflow above.
- **No AI attribution.** No `Co-Authored-By` trailers for AI agents in commits, and no "Generated with …" lines in PRs. The human who asked for the change is the author.
- Never bypass signing (`--no-gpg-sign`, `-c commit.gpgSign=false`). If signing fails, stop and say why.
- Prefer small, reviewable PRs. If a change needs a decision the user hasn't made (removing a tool, changing a keybinding), ask first.
- In GitHub, mention `@claude` on an issue or PR to have the action work on it. Every PR also gets an automatic Claude review against these rules.

## Issues

Use the templates: **New machine setup problem** for installer failures, **Config bug** for something misbehaving on a set-up machine, **Config change or new tool** for everything else.
