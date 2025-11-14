# Claude Code Workspace

A structured environment for managing prompts, commands, and AI workflows with Claude Code.

## 📁 Directory Structure

```
claude-workspace/
├── prompts/          # Reusable prompt templates
├── commands/         # Executable scripts and tools
├── agents/           # Sub-agent configurations
├── examples/         # Example workflows and usage
├── output/           # Generated content (link to Obsidian vault)
└── README.md         # This file
```

## 🚀 Quick Start

### 1. Setup Environment

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Claude Code Workspace
export CLAUDE_WORKSPACE="$HOME/claude-workspace"
export PATH="$CLAUDE_WORKSPACE/commands:$PATH"

# Optional: Link to your Obsidian vault
export OBSIDIAN_VAULT="$HOME/Documents/Obsidian/MyVault"

# Aliases for quick access
alias cw='cd $CLAUDE_WORKSPACE'
alias ccp='cd $CLAUDE_WORKSPACE/prompts'
alias cce='cd $CLAUDE_WORKSPACE/examples'
```

### 2. Install Dependencies

```bash
# For YouTube extraction
brew install yt-dlp jq  # macOS
# or
apt install yt-dlp jq   # Linux

# Claude Code (if not already installed)
# Follow: https://docs.claude.com/en/docs/claude-code
```

## 📝 Prompts

Store reusable prompt templates in `/prompts/`. These are instruction sets that can be referenced by commands or passed to Claude Code.

### Naming Convention
- Use kebab-case: `extract-youtube-knowledge.md`
- Be descriptive: `analyze-code-architecture.md`
- Include purpose in header

### Example Usage
```bash
# Reference a prompt in Claude Code
claude-code "@prompts/extract-youtube-knowledge.md analyze this transcript..."

# Or pipe content
cat transcript.txt | claude-code "@prompts/extract-youtube-knowledge.md"
```

## 🔧 Commands

Executable scripts in `/commands/` that automate workflows.

### Current Commands

#### `yt-extract`
Extract knowledge from YouTube videos into Obsidian notes.

```bash
yt-extract "https://youtube.com/watch?v=VIDEO_ID" "output-name"
```

### Creating New Commands

1. Create script in `/commands/`
2. Make executable: `chmod +x commands/your-command`
3. Use the template structure (see `yt-extract` for reference)
4. Add documentation below

## 🤖 Agents

Sub-agents are specialized Claude Code configurations for specific tasks.

### Agent Structure
```
agents/
└── code-reviewer/
    ├── config.json
    ├── instructions.md
    └── examples/
```

### Example Agent Config
```json
{
  "name": "code-reviewer",
  "model": "claude-sonnet-4-5",
  "temperature": 0.3,
  "system_prompt": "@agents/code-reviewer/instructions.md",
  "tools": ["read", "write", "search"]
}
```

## 💡 Workflow Examples

### 1. YouTube → Obsidian Pipeline
```bash
# Extract knowledge from a video
yt-extract "https://youtube.com/watch?v=dQw4w9WgXcQ" "ai-engineering-tips"

# Output appears in: $OBSIDIAN_VAULT/ai-engineering-tips.md
```

### 2. Code Review Agent
```bash
# Review current git diff
git diff | claude-code "@agents/code-reviewer review this diff"

# Review specific file
claude-code "@agents/code-reviewer review $(cat src/main.py)"
```

### 3. Research Assistant
```bash
# Summarize multiple sources
cat article1.txt article2.txt | claude-code "@prompts/research-synthesis.md"
```

## 🔄 Git Integration

### Track Your Prompts
```bash
cd $CLAUDE_WORKSPACE
git init
git add .
git commit -m "Initial prompt library"
git remote add origin YOUR_REPO
git push -u origin main
```

### Version Control Best Practices
- Commit prompt iterations
- Tag stable versions: `git tag -a v1.0 -m "Stable prompt library"`
- Branch for experiments: `git checkout -b experiment/new-extraction-format`
- Keep a CHANGELOG.md

## 🎯 Best Practices

### Prompt Design
1. **Be Specific**: Clear instructions produce better results
2. **Include Examples**: Show desired output format
3. **Iterate**: Version your prompts, test and refine
4. **Modular**: Create small, composable prompts

### Command Design
1. **Error Handling**: Check dependencies and input
2. **Helpful Output**: Use colors and clear messages
3. **Configurability**: Use environment variables
4. **Documentation**: Help text and examples

### Neovim Integration
Add to your `init.lua` or `init.vim`:

```lua
-- Quick access to Claude workspace
vim.keymap.set('n', '<leader>cp', ':e $CLAUDE_WORKSPACE/prompts/<CR>')
vim.keymap.set('n', '<leader>cc', ':e $CLAUDE_WORKSPACE/commands/<CR>')

-- Send buffer to Claude Code
vim.keymap.set('n', '<leader>ca', ':w !claude-code "@prompts/analyze-code.md"<CR>')

-- Visual selection to Claude
vim.keymap.set('v', '<leader>ce', '"zy:!claude-code <C-r>z<CR>')
```

## 📚 Prompt Library Ideas

- `summarize-technical-doc.md` - Extract key points from documentation
- `explain-code.md` - Break down complex code
- `generate-tests.md` - Create test cases
- `write-commit-message.md` - Generate semantic commit messages
- `review-pr.md` - Structured PR review
- `debug-error.md` - Debug error messages
- `refactor-suggestions.md` - Suggest code improvements
- `api-documentation.md` - Document APIs
- `meeting-notes.md` - Structure meeting transcripts

## 🔗 Resources

- [Claude Code Documentation](https://docs.claude.com/en/docs/claude-code)
- [Prompt Engineering Guide](https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview)
- [Obsidian Documentation](https://help.obsidian.md/)

## 🤝 Contributing

This is your personal workspace, but consider:
- Sharing successful prompts with your team
- Contributing to a team prompt library
- Documenting workflows that work well

---

**Last Updated**: $(date +%Y-%m-%d)
**Claude Model**: claude-sonnet-4-5
