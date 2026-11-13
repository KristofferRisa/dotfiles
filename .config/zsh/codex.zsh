# cx: Codex with the Synapse panel beside it.
#
# Codex's status line cannot run a command, so the SYNAPSE and IMPACT rows the
# Claude and Grok status lines show come from `synapse context --watch` in a
# small tmux pane below. Outside tmux, or without synapse, cx is plain codex.
# Arguments go to codex unchanged: `cx resume --last`, `cx -m <model>`.
cx() {
  if [[ -n "$TMUX" ]] && (( $+commands[synapse] )); then
    local pane
    # 14 rows: the whole view, SYNAPSE and IMPACT at the top included.
    pane="$(tmux split-window -v -d -l 14 -c "$PWD" -P -F '#{pane_id}' \
      "synapse context --harness codex --watch 5")"
    codex "$@"
    local code=$?
    [[ -n "$pane" ]] && tmux kill-pane -t "$pane" 2>/dev/null
    return $code
  fi
  codex "$@"
}
