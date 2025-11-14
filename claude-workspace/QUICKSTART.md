# Claude Code Workspace - Quick Reference

## 📁 Directory Structure
```
claude-workspace/
├── prompts/                          # Reusable prompt templates
│   ├── extract-youtube-knowledge.md  # YouTube → Obsidian
│   ├── generate-commit-message.md    # Git commit messages
│   └── explain-code.md               # Code explanations
├── commands/                         # Executable scripts
│   └── yt-extract                    # YouTube extractor
├── agents/                           # Specialized sub-agents
│   └── code-reviewer.md              # Code review agent
├── examples/                         # Usage examples
│   ├── youtube-extraction.md
│   ├── neovim-integration.md
│   └── advanced-workflows.md
├── output/                           # Generated files
├── setup.sh                          # Initial setup script
└── README.md                         # Full documentation
```

## ⚡ Quick Start

```bash
# 1. Run setup
./setup.sh

# 2. Reload shell
source ~/.bashrc  # or ~/.zshrc

# 3. Try it out
yt-extract "https://youtube.com/watch?v=..." "my-notes"
```

## 🎯 Common Commands

### YouTube Extraction
```bash
# Extract video knowledge
yt-extract "VIDEO_URL" "note-name"

# From clipboard
yt-extract "$(pbpaste)" "note-name"  # macOS
yt-extract "$(xclip -o)" "note-name" # Linux
```

### Code Review
```bash
# Review current changes
git diff | claude-code "@agents/code-reviewer.md"

# Review specific file
claude-code "@agents/code-reviewer.md" < file.py
```

### Generate Commit Message
```bash
# From staged changes
git diff --cached | claude-code "@prompts/generate-commit-message.md"

# Shortcut
alias gcm='git diff --cached | claude-code "@prompts/generate-commit-message.md"'
```

### Explain Code
```bash
# Explain a file
claude-code "@prompts/explain-code.md" < complex-file.py

# Pipe to file
cat code.js | claude-code "@prompts/explain-code.md" > explanation.md
```

## 🔧 Environment Variables

```bash
export CLAUDE_WORKSPACE="$HOME/claude-workspace"
export OBSIDIAN_VAULT="$HOME/Documents/Obsidian/MyVault"
export PATH="$CLAUDE_WORKSPACE/commands:$PATH"
```

## 💡 Aliases

Add to your shell config:

```bash
# Navigation
alias cw='cd $CLAUDE_WORKSPACE'
alias ccp='cd $CLAUDE_WORKSPACE/prompts'
alias ccc='cd $CLAUDE_WORKSPACE/commands'
alias cca='cd $CLAUDE_WORKSPACE/agents'

# Quick prompts
alias ce='claude-code "@prompts/explain-code.md"'
alias cr='claude-code "@agents/code-reviewer.md"'
alias cgc='git diff --cached | claude-code "@prompts/generate-commit-message.md"'

# YouTube
alias yt='yt-extract'
```

## 🎨 Neovim Key Bindings

| Key | Action |
|-----|--------|
| `<leader>cw` | CD to workspace |
| `<leader>cp` | Open prompts |
| `<leader>cc` | Open commands |
| `<leader>ca` | Open agents |
| `<leader>ce` | Execute on buffer |
| `<leader>cs` | Execute on selection |
| `<leader>cr` | Review current file |
| `<leader>cgc` | Generate commit |
| `<leader>cyt` | YouTube extract |

See `examples/neovim-integration.md` for full config.

## 📝 Creating New Prompts

1. **Create the file:**
   ```bash
   vim $CLAUDE_WORKSPACE/prompts/my-new-prompt.md
   ```

2. **Use the template:**
   ```markdown
   # Prompt Title
   
   ## Purpose
   What this prompt does
   
   ## Instructions
   1. Step one
   2. Step two
   
   ## Output Format
   Expected output structure
   
   ## Examples
   Example inputs and outputs
   ```

3. **Test it:**
   ```bash
   echo "test input" | claude-code "@prompts/my-new-prompt.md"
   ```

4. **Commit it:**
   ```bash
   git add prompts/my-new-prompt.md
   git commit -m "feat(prompts): add my-new-prompt"
   ```

## 🤖 Creating Commands

1. **Create executable script:**
   ```bash
   vim $CLAUDE_WORKSPACE/commands/my-command
   chmod +x $CLAUDE_WORKSPACE/commands/my-command
   ```

2. **Basic structure:**
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   
   # Your logic here
   claude-code "@prompts/some-prompt.md" < input.txt
   ```

3. **Test it:**
   ```bash
   my-command arg1 arg2
   ```

## 🔄 Common Workflows

### Full Feature Development
```bash
# 1. Plan
claude-code "Plan implementation for: FEATURE" > plan.md

# 2. Generate tests
claude-code "@prompts/generate-tests.md Create tests for: FEATURE"

# 3. Code (manual or assisted)

# 4. Review
git diff | claude-code "@agents/code-reviewer.md"

# 5. Document
claude-code "@prompts/api-documentation.md" < src/feature.py

# 6. Commit
git add . && git commit -m "$(gcm)"
```

### Research Pipeline
```bash
# Extract → Analyze → Synthesize
yt-extract "URL" "raw-notes" && \
cat output/raw-notes.md | \
  claude-code "Analyze key insights" > analysis.md && \
cat analysis.md | \
  claude-code "Create action plan" > action-plan.md
```

### Daily Developer Assistant
```bash
# Morning standup
claude-code "Generate standup from: 
$(git log --author=me --since=yesterday --oneline)
$(gh issue list --assignee @me)"

# Code all day with reviews
git diff | cr  # cr is alias for code-reviewer

# Evening commit
git add . && git commit -m "$(gcm)"
```

## 🐛 Troubleshooting

### Command not found
```bash
# Check PATH
echo $PATH | grep claude-workspace

# Re-source shell
source ~/.bashrc
```

### Prompt not working
```bash
# Verify prompt exists
ls $CLAUDE_WORKSPACE/prompts/

# Check syntax
cat $CLAUDE_WORKSPACE/prompts/your-prompt.md
```

### YouTube extraction fails
```bash
# Check dependencies
which yt-dlp jq

# Test manually
yt-dlp --list-formats "VIDEO_URL"
```

## 📚 Resources

- Full docs: `$CLAUDE_WORKSPACE/README.md`
- Examples: `$CLAUDE_WORKSPACE/examples/`
- Claude Code docs: https://docs.claude.com/en/docs/claude-code

## 🚀 Next Steps

1. ✅ Complete setup with `./setup.sh`
2. ✅ Try YouTube extraction
3. ✅ Add Neovim integration
4. ✅ Create your first custom prompt
5. ✅ Set up git workflow
6. ✅ Customize for your needs

## 💬 Tips

- Start with the built-in prompts and modify them
- Version control your prompts (they're valuable!)
- Share useful prompts with your team
- Create project-specific agents
- Iterate on prompts - they get better with use
- Combine simple prompts for complex tasks
- Use environment variables for flexibility

---

**Happy coding with Claude! 🤖**

For detailed information, see the full README.md
