## What and why

<!-- What changes on a machine after this merges, and why. -->

## Test plan

<!-- CI runs lint, a secret scan, and a fresh install on macOS and Linux.
     List what you checked by hand on a real machine. -->

- [ ] Opened a new shell / tmux / nvim and it behaves as described
- [ ] `./install.sh --dry-run` shows nothing unexpected (installer changes only)

## Checklist

- [ ] README.md and CLAUDE.md still match (aliases, keys, installer steps)
- [ ] Nothing machine-specific or secret is committed (use `.zshrc.local`)
- [ ] New Homebrew dependency added to `BREW_PACKAGES` (if any)
