# Enable Powerlevel10k instant prompt. Must stay at the top of .zshrc: below
# oh-my-zsh it does nothing. Anything that needs console input (password
# prompts, [y/n] confirmations) must go above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Homebrew, wherever this machine keeps it: Apple Silicon, Intel Mac, Linux.
# A hardcoded path breaks every machine but the one it was written on.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [[ -x "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
    break
  fi
done
unset brew_bin

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="powerlevel10k/powerlevel10k"
# ZSH_THEME="bira"
CASE_SENSITIVE="true"
ENABLE_CORRECTION="true"

plugins=(git)

source $ZSH/oh-my-zsh.sh

export EDITOR='nvim'

# Source environment-specific variables
if [[ -f ~/.config/zsh/.zshrc.local ]]; then
  source ~/.config/zsh/.zshrc.local
fi

# -------
# Aliases
# -------
alias l="ls" # List files in current directory
alias ll="ls -al" # List all files in current directory in long list format
alias n='nvim .'
alias dtable='docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dstart='docker compose up -d && docker compose logs -f -n 1000'

# Open the current directory in the file manager (Finder on macOS)
if [[ "$OSTYPE" == darwin* ]]; then
  alias o="open ."
else
  alias o="xdg-open ."
fi
#----------------------
# Claude Aliases
# ----------------------
alias cc='claude'
alias oc='opencode'

# Turn on Claude Code's OpenTelemetry export. Where it goes (exporter,
# endpoint, headers) is per machine, so that belongs in .zshrc.local.
export CLAUDE_CODE_ENABLE_TELEMETRY=1

# ----------------------
# Git Aliases
# ----------------------
alias gaa='git add .'
alias gcm='git commit -m'
alias gpsh='git push'
alias gss='git status -s'

# To customize prompt, run `p10k configure` or edit ~/.config/zsh/.p10k.zsh.
# ZDOTDIR points zsh here, so that is where the wizard writes it — and where
# it is tracked, so a new machine gets the same prompt without the wizard.
[[ ! -f "${ZDOTDIR:-$HOME}/.p10k.zsh" ]] || source "${ZDOTDIR:-$HOME}/.p10k.zsh"

## fabric config
# export OPENAI_BASE_URL=https://YOUR-SERVER:8000/v1/
# export DEFAULT_MODEL="YOUR_MODEL"
# if [ -f "/Users/[UserName]/.config/fabric/fabric-bootstrap.inc" ]; then . "/Users/[UserName]/.config/fabric/fabric-bootstrap.inc"; fi

# Source the Tmux-related Zsh configurations
source ~/.config/zsh/tmux.zsh
source ~/.config/zsh/powerctl.zsh
source ~/.config/zsh/sky.zsh
source ~/.config/zsh/mouse.zsh

# # ----------
# # AZ completion
# # ----------
#
# autoload bashcompinit && bashcompinit
# source $(brew --prefix)/etc/bash_completion.d/az

# $(tty) prints "not a tty" under instant prompt; $TTY is set by zsh.
export GPG_TTY=$TTY

# opencode
export PATH=~/.opencode/bin:$PATH
export PATH="$HOME/dotfiles/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"


# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
