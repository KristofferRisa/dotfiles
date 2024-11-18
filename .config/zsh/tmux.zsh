# Enhanced Tmux alias function with session check, auto-create, and tab completion
tmx() {
    if [[ -z "$1" ]]; then
        echo "Usage: tmx <session_name_or_id>"
        return 1
    fi

    # Check if the session exists
    if tmux has-session -t "$1" 2>/dev/null; then
        tmux attach-session -t "$1"
    else
        echo "No such session: $1"
        read "create?Would you like to create a new session named '$1'? (y/n): "
        if [[ "$create" =~ ^[Yy]$ ]]; then
            tmux new-session -s "$1"
        else
            echo "Available sessions:"
            tmux list-sessions
        fi
    fi
}

# Tmux session name tab completion
_tmx_sessions() {
    compadd $(tmux list-sessions -F "#{session_name}" 2>/dev/null)
}

compdef _tmx_sessions tmx
