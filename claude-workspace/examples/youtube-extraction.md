# Example: YouTube Knowledge Extraction Workflow

This example demonstrates how to extract knowledge from YouTube videos and save as Obsidian notes.

## Prerequisites
```bash
brew install yt-dlp jq  # or apt install
```

## Basic Usage

### Extract a single video
```bash
yt-extract "https://www.youtube.com/watch?v=dQw4w9WgXcQ" "my-video-notes"
```

### Process and pipe to Claude Code
```bash
# Download transcript
yt-dlp --skip-download --write-auto-sub --sub-lang en \
  --convert-subs srt "VIDEO_URL" -o transcript

# Process with Claude
cat transcript.en.srt | \
  claude-code "$(cat $CLAUDE_WORKSPACE/prompts/extract-youtube-knowledge.md) 

Process this transcript:"
```

## Advanced Workflows

### 1. Batch Processing Multiple Videos
```bash
# Create a playlist file
cat > my-playlist.txt << EOF
https://youtube.com/watch?v=VIDEO1
https://youtube.com/watch?v=VIDEO2
https://youtube.com/watch?v=VIDEO3
EOF

# Process each
while read url; do
  yt-extract "$url"
  sleep 5  # Rate limiting
done < my-playlist.txt
```

### 2. Integration with Obsidian Daily Notes
```bash
#!/bin/bash
# Add video summary to today's daily note

VIDEO_URL="$1"
DAILY_NOTE="$OBSIDIAN_VAULT/Daily/$(date +%Y-%m-%d).md"

echo -e "\n## Video Notes\n" >> "$DAILY_NOTE"
yt-extract "$VIDEO_URL" "temp" >> "$DAILY_NOTE"
```

### 3. Neovim Integration
Add to your `init.lua`:

```lua
-- Extract YouTube video from clipboard
vim.keymap.set('n', '<leader>yt', function()
  local url = vim.fn.getreg('+')  -- Get from clipboard
  local name = vim.fn.input('Note name: ')
  local cmd = string.format('!yt-extract "%s" "%s"', url, name)
  vim.cmd(cmd)
end, { desc = 'Extract YouTube video to notes' })

-- Quick prompt access
vim.keymap.set('n', '<leader>yp', ':e $CLAUDE_WORKSPACE/prompts/extract-youtube-knowledge.md<CR>')
```

## Output Structure

The generated markdown will look like:

```markdown
---
title: "Video Title"
channel: "Channel Name"
date: 2024-01-15
url: https://youtube.com/watch?v=...
tags: [youtube, ai, programming]
---

# Video Title

## Executive Summary
[2-3 sentence overview]

## Main Concepts
### [[Concept 1]]
- Details
- Examples

### [[Concept 2]]
- Details

## Key Insights
> [!important] Key Quote
> "Important statement from video"

## Technical Details
- Tools: [[Tool1]], [[Tool2]]
- Process:
  1. Step one
  2. Step two

## Personal Notes
[Your thoughts here]

## Related Topics
- [[Related Topic 1]]
- [[Related Topic 2]]
```

## Customization

### Modify the Prompt
Edit `prompts/extract-youtube-knowledge.md` to:
- Change output format
- Add more sections
- Adjust tone
- Include different metadata

### Custom Post-Processing
```bash
# Add custom tags based on content
yt-extract "URL" "name" | \
  sed 's/tags: \[/tags: [my-custom-tag, /'
```

## Tips

1. **Video Selection**: Works best with educational/tutorial content
2. **Transcript Quality**: Auto-generated transcripts may have errors
3. **Length**: Very long videos (2+ hours) may need splitting
4. **Rate Limiting**: Add delays when batch processing
5. **Token Limits**: For very long transcripts, consider summarizing first

## Troubleshooting

### No transcript available
```bash
# Check available subtitles
yt-dlp --list-subs "VIDEO_URL"

# Try different language
yt-extract --sub-lang es "VIDEO_URL"
```

### Claude Code timeout
```bash
# For long transcripts, pre-summarize
cat transcript.txt | \
  claude-code "Summarize in 2000 words" | \
  claude-code "@prompts/extract-youtube-knowledge.md"
```

## Next Steps

- Create specialized prompts for different video types
- Build a video library manager
- Add automatic tagging based on content
- Create weekly digest of watched videos
