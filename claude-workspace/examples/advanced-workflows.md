# Advanced Workflow Patterns

This document contains advanced patterns and ideas for your Claude Code workspace.

## 🔄 Workflow Patterns

### 1. Chain of Thought Workflows

Combine multiple prompts in sequence for complex tasks:

```bash
# Research → Analyze → Document pipeline
cat source.txt | \
  claude-code "@prompts/research-synthesis.md" | \
  claude-code "@prompts/analyze-findings.md" | \
  claude-code "@prompts/create-documentation.md" > output.md
```

### 2. Context-Aware Prompts

Inject project context automatically:

```bash
#!/bin/bash
# smart-review.sh - Context-aware code review

PROJECT_CONTEXT=$(cat <<EOF
Project: $(basename $PWD)
Language: $(head -1 .tool-versions 2>/dev/null || echo "unknown")
Recent commits: $(git log --oneline -3)
Open issues: $(gh issue list --limit 3 2>/dev/null)
EOF
)

cat "$1" | claude-code "
Context: $PROJECT_CONTEXT

$(cat $CLAUDE_WORKSPACE/agents/code-reviewer.md)

Review this code:
"
```

### 3. Interactive Workflows

Create interactive prompts with fzf:

```bash
# prompt-selector.sh
PROMPT=$(ls $CLAUDE_WORKSPACE/prompts/*.md | \
  fzf --preview 'bat --color=always {}' \
      --preview-window=right:60%)

if [ -n "$PROMPT" ]; then
  cat file.txt | claude-code "$(cat $PROMPT)"
fi
```

### 4. Git Hook Integration

`.git/hooks/prepare-commit-msg`:
```bash
#!/bin/bash
COMMIT_MSG_FILE=$1
COMMIT_SOURCE=$2

# Generate commit message from staged changes
if [ -z "$COMMIT_SOURCE" ]; then
  DIFF=$(git diff --cached)
  if [ -n "$DIFF" ]; then
    MSG=$(echo "$DIFF" | claude-code \
      "@prompts/generate-commit-message.md Generate a commit message:")
    echo "$MSG" > "$COMMIT_MSG_FILE"
  fi
fi
```

### 5. Watch Mode for Documentation

Auto-update docs when code changes:

```bash
# doc-watch.sh
while inotifywait -e modify src/; do
  claude-code "@prompts/api-documentation.md Document this:" \
    < src/main.py > docs/api.md
done
```

## 🎯 Sub-Agent Patterns

### Specialized Agents

Create domain-specific agents:

```
agents/
├── code-reviewer.md          # Code quality
├── security-auditor.md        # Security issues
├── performance-optimizer.md   # Performance
├── documentation-writer.md    # Docs
└── test-generator.md          # Test cases
```

### Agent Orchestration

```bash
# multi-agent-review.sh
FILE="$1"

echo "## Code Review Report" > report.md
echo "" >> report.md

for agent in $CLAUDE_WORKSPACE/agents/*.md; do
  AGENT_NAME=$(basename "$agent" .md)
  echo "### ${AGENT_NAME//-/ }" >> report.md
  cat "$FILE" | claude-code "$(cat $agent)" >> report.md
  echo "" >> report.md
done
```

## 📊 Data Processing Pipelines

### Log Analysis

```bash
# analyze-logs.sh
tail -n 1000 app.log | \
  grep ERROR | \
  claude-code "Analyze these errors and suggest fixes:"
```

### CSV Data Analysis

```bash
# analyze-data.sh
claude-code "$(cat <<EOF
Analyze this CSV data and provide:
1. Summary statistics
2. Anomalies or patterns
3. Visualization suggestions
4. Action items

Data:
$(cat data.csv)
EOF
)"
```

## 🔧 Development Workflows

### Feature Development Flow

```bash
# feature-flow.sh
FEATURE="$1"

# 1. Create feature branch
git checkout -b "feature/$FEATURE"

# 2. Generate implementation plan
claude-code "Create implementation plan for: $FEATURE" > plan.md

# 3. Generate tests first (TDD)
claude-code "@prompts/generate-tests.md Create tests for: $FEATURE" > test_$FEATURE.py

# 4. Implement feature
# ... (manual coding or with Claude assistance)

# 5. Review implementation
git diff | claude-code "@agents/code-reviewer.md"

# 6. Generate documentation
claude-code "@prompts/api-documentation.md" < src/$FEATURE.py > docs/$FEATURE.md

# 7. Create PR description
git diff main | claude-code "Create a detailed PR description"
```

### Debugging Assistant

```bash
# debug-helper.sh
ERROR_LOG="$1"

claude-code "$(cat <<EOF
I'm seeing this error:

$(cat $ERROR_LOG)

Context:
- File: $(grep -l "$(head -1 $ERROR_LOG)" src/*)
- Recent changes: $(git log --oneline -5)
- Environment: $(cat .env.example)

Help me:
1. Understand the root cause
2. Suggest fixes
3. Recommend preventive measures
EOF
)"
```

## 📚 Knowledge Management

### Meeting Notes Processor

```bash
# process-meeting.sh
MEETING_NOTES="$1"

claude-code "$(cat <<EOF
Process these meeting notes:

$(cat $MEETING_NOTES)

Create:
1. Action items with owners
2. Decisions made
3. Topics for follow-up
4. Summary for stakeholders

Format as Obsidian note with tags and links.
EOF
)" > "${MEETING_NOTES%.txt}-processed.md"
```

### Daily Standup Generator

```bash
# standup.sh
YESTERDAY=$(date -d yesterday +%Y-%m-%d)

claude-code "$(cat <<EOF
Generate my standup update based on:

Commits yesterday:
$(git log --author="$(git config user.name)" --since="$YESTERDAY 00:00" --oneline)

PRs:
$(gh pr list --author @me)

Issues:
$(gh issue list --assignee @me)

Format:
- What I did yesterday
- What I'm doing today
- Any blockers
EOF
)"
```

## 🎨 Creative Workflows

### Blog Post Generator

```bash
# blog-from-code.sh
CODE_FILE="$1"
TITLE="$2"

claude-code "$(cat <<EOF
Create a blog post titled "$TITLE" that:
1. Explains this code example
2. Includes learning points
3. Has practical applications
4. Suggests next steps

Code:
$(cat $CODE_FILE)

Style: Developer blog, conversational, with code examples
EOF
)" > "blog-$TITLE.md"
```

### README Generator

```bash
# auto-readme.sh
claude-code "$(cat <<EOF
Generate a comprehensive README.md based on this project:

Project structure:
$(tree -L 2)

Main files:
$(ls -la)

Dependencies:
$(cat package.json 2>/dev/null || cat requirements.txt 2>/dev/null)

Code sample:
$(find src -name "*.py" -o -name "*.js" | head -1 | xargs cat)

Include:
- Project description
- Installation steps
- Usage examples
- API documentation
- Contributing guidelines
EOF
)"
```

## 🔍 Quality Assurance

### Pre-commit Quality Gate

`.git/hooks/pre-commit`:
```bash
#!/bin/bash
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

for FILE in $STAGED_FILES; do
  # Run multiple checks
  ISSUES=$(cat "$FILE" | claude-code "Quick review for issues: security, bugs, style")
  
  if echo "$ISSUES" | grep -q "CRITICAL"; then
    echo "Critical issues found in $FILE:"
    echo "$ISSUES"
    exit 1
  fi
done
```

### Dependency Audit

```bash
# audit-deps.sh
claude-code "$(cat <<EOF
Review these dependencies for:
1. Security vulnerabilities
2. Outdated versions
3. Unused dependencies
4. License compatibility

Dependencies:
$(cat package-lock.json)

Project: Open source, MIT licensed
EOF
)"
```

## 💡 Pro Tips

### 1. Prompt Versioning
```bash
# Tag stable prompts
cd $CLAUDE_WORKSPACE
git tag -a prompts-v1.0 -m "Stable prompt set"
```

### 2. Prompt Templates
```bash
# Create new prompt from template
cp prompts/_template.md prompts/new-prompt.md
```

### 3. Performance Optimization
```bash
# Cache Claude responses for repeated queries
CACHE_DIR="$HOME/.cache/claude-code"
mkdir -p "$CACHE_DIR"

# Hash input and check cache
INPUT_HASH=$(echo "$INPUT" | sha256sum | cut -d' ' -f1)
if [ -f "$CACHE_DIR/$INPUT_HASH" ]; then
  cat "$CACHE_DIR/$INPUT_HASH"
else
  claude-code "$INPUT" | tee "$CACHE_DIR/$INPUT_HASH"
fi
```

### 4. Batch Processing
```bash
# Process multiple files in parallel
find src/ -name "*.py" | \
  xargs -P 4 -I {} bash -c \
    'claude-code "@prompts/explain-code.md" < {} > docs/$(basename {}).md'
```

### 5. Integration with Other Tools

**tmux integration:**
```bash
# Send Claude output to tmux pane
claude-code "analyze this" | tmux load-buffer -
```

**Slack notification:**
```bash
# Notify team of review completion
REVIEW=$(claude-code "@agents/code-reviewer.md" < PR.diff)
slack-cli post -c code-review "PR Review complete: $REVIEW"
```

## 🚀 Next Level

### Custom Claude Code Wrapper

```python
#!/usr/bin/env python3
# claude.py - Enhanced Claude Code wrapper

import sys
import subprocess
import os
from pathlib import Path

WORKSPACE = Path(os.environ['CLAUDE_WORKSPACE'])

def load_prompt(name):
    """Load prompt from workspace"""
    prompt_file = WORKSPACE / 'prompts' / f'{name}.md'
    if prompt_file.exists():
        return prompt_file.read_text()
    raise FileNotFoundError(f"Prompt not found: {name}")

def claude_code(prompt, input_text=None):
    """Execute Claude Code with prompt"""
    cmd = ['claude-code', prompt]
    result = subprocess.run(
        cmd,
        input=input_text,
        text=True,
        capture_output=True
    )
    return result.stdout

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: claude <prompt-name> [input-file]")
        sys.exit(1)
    
    prompt_name = sys.argv[1]
    prompt = load_prompt(prompt_name)
    
    input_text = None
    if len(sys.argv) > 2:
        with open(sys.argv[2]) as f:
            input_text = f.read()
    elif not sys.stdin.isatty():
        input_text = sys.stdin.read()
    
    output = claude_code(prompt, input_text)
    print(output)
```

This gives you a cleaner interface:
```bash
claude extract-youtube-knowledge transcript.txt
cat code.py | claude explain-code
```
