# A fullscreen program that dies during sleep (or a stuck mouse button after
# wake) can leave the terminal in mouse-tracking mode. Ghostty then writes a
# report for every move, and zsh inserts it into the command line.

[[ -n ${_ZSH_MOUSE_TRACKING_GUARD-} ]] && return
typeset -g _ZSH_MOUSE_TRACKING_GUARD=1

_zsh_disable_mouse_tracking() {
  [[ -t 1 ]] || return
  # 1000 click, 1002 drag, 1003 any-motion, 1006 SGR, 1015 urxvt, 1004 focus.
  printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l\e[?1015l\e[?1004l'
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _zsh_disable_mouse_tracking
trap '_zsh_disable_mouse_tracking' CONT

# The prompt is already open after wake, so precmd will not run again until
# the next command. Swallow reports that arrive in the meantime.
_zsh_discard_sgr_mouse() {
  _zsh_disable_mouse_tracking
  local c
  while read -s -t 0.1 -k 1 c; do
    [[ $c == [Mm] ]] && break
  done
}
zle -N _zsh_discard_sgr_mouse
bindkey -M emacs '\e[<' _zsh_discard_sgr_mouse
bindkey -M viins '\e[<' _zsh_discard_sgr_mouse
bindkey -M vicmd '\e[<' _zsh_discard_sgr_mouse

# Legacy X10 reports are ESC [ M plus three bytes.
_zsh_discard_x10_mouse() {
  _zsh_disable_mouse_tracking
  local c
  read -s -t 0.1 -k 3 c
}
zle -N _zsh_discard_x10_mouse
bindkey -M emacs '\e[M' _zsh_discard_x10_mouse
bindkey -M viins '\e[M' _zsh_discard_x10_mouse
bindkey -M vicmd '\e[M' _zsh_discard_x10_mouse
