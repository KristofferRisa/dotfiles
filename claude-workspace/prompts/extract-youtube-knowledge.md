# Extract YouTube Knowledge

## Purpose
Extract structured, actionable knowledge from YouTube video transcripts and format as Obsidian-friendly markdown.

## Instructions
Analyze the provided YouTube transcript and create a comprehensive knowledge extraction with:

1. **Video Metadata** (if provided)
   - Title
   - Channel
   - Date
   - URL

2. **Executive Summary**
   - 2-3 sentence overview of main points
   - Key takeaway

3. **Main Concepts**
   - Core ideas and themes
   - Supporting details
   - Examples or case studies mentioned

4. **Key Insights**
   - Important quotes or statements
   - Novel or surprising information
   - Actionable recommendations

5. **Technical Details** (if applicable)
   - Tools, technologies, or methods mentioned
   - Step-by-step processes
   - Resources referenced

6. **Personal Notes Section**
   - Leave empty for user's own thoughts
   - Tag suggestions based on content

7. **Related Topics & Links**
   - Topics for further exploration
   - Mentioned resources or references

## Output Format
- Use Obsidian-friendly markdown
- Include frontmatter with metadata
- Use `[[wikilinks]]` for concept connections
- Add relevant `#tags`
- Create subsections with `##` and `###`
- Use callouts for important notes: `> [!note]`, `> [!important]`, `> [!tip]`

## Style
- Clear, concise, scannable
- Preserve technical accuracy
- Extract verbatim key quotes
- Highlight actionable items with checkboxes `- [ ]`
