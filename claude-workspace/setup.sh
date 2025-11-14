#!/usr/bin/env bash
# setup.sh - Initialize Claude Code workspace
set -e

WORKSPACE_DIR="${HOME}/claude-workspace"
SHELL_RC="${HOME}/.$(basename $SHELL)rc"

echo "🚀 Setting up Claude Code Workspace..."

# Check if workspace already exists
if [ -d "$WORKSPACE_DIR" ]; then
    echo "⚠️  Workspace already exists at $WORKSPACE_DIR"
    read -p "Reinitialize? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Create directory structure
echo "📁 Creating directory structure..."
mkdir -p "$WORKSPACE_DIR"/{prompts,commands,agents,examples,output}
touch "$WORKSPACE_DIR/output/.gitkeep"

# Initialize git
echo "🔧 Initializing git repository..."
cd "$WORKSPACE_DIR"
git init
git add .
git commit -m "Initial commit: Claude Code workspace structure"

# Add to shell RC
echo ""
echo "📝 Shell configuration:"
echo "Add the following to your $SHELL_RC:"
echo ""
echo "# Claude Code Workspace"
echo "export CLAUDE_WORKSPACE=\"\$HOME/claude-workspace\""
echo "export PATH=\"\$CLAUDE_WORKSPACE/commands:\$PATH\""
echo ""
echo "# Optional: Link to Obsidian vault"
echo "export OBSIDIAN_VAULT=\"\$HOME/Documents/Obsidian/YourVault\""
echo ""
echo "# Aliases"
echo "alias cw='cd \$CLAUDE_WORKSPACE'"
echo "alias ccp='cd \$CLAUDE_WORKSPACE/prompts'"
echo ""

read -p "Add these lines automatically? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cat >> "$SHELL_RC" << 'EOF'

# Claude Code Workspace
export CLAUDE_WORKSPACE="$HOME/claude-workspace"
export PATH="$CLAUDE_WORKSPACE/commands:$PATH"

# Aliases
alias cw='cd $CLAUDE_WORKSPACE'
alias ccp='cd $CLAUDE_WORKSPACE/prompts'
EOF
    echo "✅ Added to $SHELL_RC"
    echo "Run: source $SHELL_RC"
fi

# Check dependencies
echo ""
echo "🔍 Checking dependencies..."
MISSING_DEPS=()

if ! command -v yt-dlp &> /dev/null; then
    MISSING_DEPS+=("yt-dlp")
fi

if ! command -v jq &> /dev/null; then
    MISSING_DEPS+=("jq")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "⚠️  Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Install with: brew install ${MISSING_DEPS[*]}"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Install with: apt install ${MISSING_DEPS[*]}"
    fi
else
    echo "✅ All dependencies installed"
fi

echo ""
echo "✨ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Source your shell: source $SHELL_RC"
echo "2. Read the README: cat \$CLAUDE_WORKSPACE/README.md"
echo "3. Try the example: yt-extract <youtube-url>"
echo ""
echo "Happy coding with Claude! 🤖"
