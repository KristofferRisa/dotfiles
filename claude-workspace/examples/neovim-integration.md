# Neovim Integration for Claude Code Workspace

## Lua Configuration (init.lua)

Add these configurations to integrate Claude Code with Neovim:

```lua
-- Claude Code Workspace Integration
local claude_workspace = vim.fn.expand('$CLAUDE_WORKSPACE')

-- Quick navigation to workspace
vim.keymap.set('n', '<leader>cw', function()
  vim.cmd('cd ' .. claude_workspace)
  print('Changed to Claude workspace')
end, { desc = 'CD to Claude workspace' })

vim.keymap.set('n', '<leader>cp', ':e ' .. claude_workspace .. '/prompts/<CR>', 
  { desc = 'Open prompts directory' })

vim.keymap.set('n', '<leader>cc', ':e ' .. claude_workspace .. '/commands/<CR>', 
  { desc = 'Open commands directory' })

vim.keymap.set('n', '<leader>ca', ':e ' .. claude_workspace .. '/agents/<CR>', 
  { desc = 'Open agents directory' })

-- Send current buffer to Claude Code with a prompt
vim.keymap.set('n', '<leader>ce', function()
  local prompt = vim.fn.input('Prompt: ')
  if prompt ~= '' then
    local filename = vim.fn.expand('%:p')
    local cmd = string.format('!claude-code "%s" < "%s"', prompt, filename)
    vim.cmd(cmd)
  end
end, { desc = 'Send buffer to Claude Code' })

-- Send visual selection to Claude Code
vim.keymap.set('v', '<leader>cs', function()
  -- Yank to register z
  vim.cmd('normal! "zy')
  local selection = vim.fn.getreg('z')
  local prompt = vim.fn.input('Prompt: ')
  if prompt ~= '' then
    -- Create temp file with selection
    local tmpfile = vim.fn.tempname()
    vim.fn.writefile(vim.split(selection, '\n'), tmpfile)
    local cmd = string.format('!claude-code "%s" < "%s"', prompt, tmpfile)
    vim.cmd(cmd)
  end
end, { desc = 'Send selection to Claude Code' })

-- Quick apply prompt to current file
vim.keymap.set('n', '<leader>cap', function()
  -- List available prompts
  local prompts_dir = claude_workspace .. '/prompts'
  local prompts = vim.fn.globpath(prompts_dir, '*.md', 0, 1)
  
  if #prompts == 0 then
    print('No prompts found')
    return
  end
  
  -- Create selection list
  local prompt_names = {}
  for _, path in ipairs(prompts) do
    table.insert(prompt_names, vim.fn.fnamemodify(path, ':t:r'))
  end
  
  vim.ui.select(prompt_names, {
    prompt = 'Select prompt:',
  }, function(choice)
    if choice then
      local prompt_file = prompts_dir .. '/' .. choice .. '.md'
      local current_file = vim.fn.expand('%:p')
      local cmd = string.format('!claude-code "$(cat %s)" < "%s"', 
        prompt_file, current_file)
      vim.cmd(cmd)
    end
  end)
end, { desc = 'Apply prompt to current file' })

-- Git commit message generation
vim.keymap.set('n', '<leader>cgc', function()
  local prompt_file = claude_workspace .. '/prompts/generate-commit-message.md'
  vim.cmd('!git diff --cached | claude-code "$(cat ' .. prompt_file .. ')"')
end, { desc = 'Generate commit message' })

-- YouTube extraction
vim.keymap.set('n', '<leader>cyt', function()
  local url = vim.fn.getreg('+')  -- Get from clipboard
  local name = vim.fn.input('Note name: ')
  if name ~= '' then
    local cmd = string.format('!yt-extract "%s" "%s"', url, name)
    vim.cmd(cmd)
  end
end, { desc = 'Extract YouTube video (from clipboard)' })

-- Code review current file
vim.keymap.set('n', '<leader>cr', function()
  local agent_file = claude_workspace .. '/agents/code-reviewer.md'
  local current_file = vim.fn.expand('%:p')
  local cmd = string.format('!claude-code "$(cat %s) Review this code:" < "%s"', 
    agent_file, current_file)
  vim.cmd(cmd)
end, { desc = 'Review current file with Claude' })

-- Telescope integration (if using Telescope)
local telescope_available, telescope = pcall(require, 'telescope')
if telescope_available then
  local builtin = require('telescope.builtin')
  
  vim.keymap.set('n', '<leader>cfp', function()
    builtin.find_files({
      prompt_title = 'Claude Prompts',
      cwd = claude_workspace .. '/prompts',
    })
  end, { desc = 'Find Claude prompts' })
  
  vim.keymap.set('n', '<leader>cfg', function()
    builtin.live_grep({
      prompt_title = 'Search Claude Workspace',
      cwd = claude_workspace,
    })
  end, { desc = 'Search Claude workspace' })
end

-- Create a user command for quick Claude queries
vim.api.nvim_create_user_command('Claude', function(opts)
  local query = opts.args
  local cmd = string.format('!claude-code "%s"', query)
  vim.cmd(cmd)
end, { nargs = '+', desc = 'Run Claude Code query' })

-- Status line indicator (optional - shows if in Claude workspace)
vim.api.nvim_create_autocmd({'BufEnter', 'DirChanged'}, {
  callback = function()
    local cwd = vim.fn.getcwd()
    if cwd:find(claude_workspace, 1, true) then
      vim.g.in_claude_workspace = true
    else
      vim.g.in_claude_workspace = false
    end
  end
})
```

## Vimscript Configuration (init.vim)

If you prefer Vimscript:

```vim
" Claude Code Workspace Integration
let g:claude_workspace = expand('$CLAUDE_WORKSPACE')

" Quick navigation
nnoremap <leader>cw :execute 'cd ' . g:claude_workspace<CR>
nnoremap <leader>cp :execute 'e ' . g:claude_workspace . '/prompts/'<CR>
nnoremap <leader>cc :execute 'e ' . g:claude_workspace . '/commands/'<CR>

" Send buffer to Claude
nnoremap <leader>ce :execute '!claude-code "' . input('Prompt: ') . '" < ' . expand('%:p')<CR>

" Generate commit message
nnoremap <leader>cgc :!git diff --cached \| claude-code "$(cat $CLAUDE_WORKSPACE/prompts/generate-commit-message.md)"<CR>

" User command
command! -nargs=+ Claude execute '!claude-code "' . <q-args> . '"'
```

## Which-key Integration

If you use which-key.nvim:

```lua
local wk = require("which-key")

wk.register({
  c = {
    name = "Claude",
    w = { "Workspace" },
    p = { "Prompts" },
    c = { "Commands" },
    a = { "Agents" },
    e = { "Execute with prompt" },
    s = { "Send selection" },
    r = { "Review code" },
    g = {
      name = "Git",
      c = { "Generate commit" },
    },
    y = {
      name = "YouTube",
      t = { "Extract from clipboard" },
    },
    f = {
      name = "Find",
      p = { "Find prompts" },
      g = { "Grep workspace" },
    },
  }
}, { prefix = "<leader>" })
```

## Recommended Key Mappings Summary

| Key | Action |
|-----|--------|
| `<leader>cw` | Go to Claude workspace |
| `<leader>cp` | Open prompts directory |
| `<leader>cc` | Open commands directory |
| `<leader>ca` | Open agents directory |
| `<leader>ce` | Execute Claude on current file |
| `<leader>cs` | Execute Claude on selection |
| `<leader>cap` | Apply prompt to file |
| `<leader>cr` | Review current file |
| `<leader>cgc` | Generate commit message |
| `<leader>cyt` | Extract YouTube (from clipboard) |
| `<leader>cfp` | Find prompts (Telescope) |

## Tips

1. **Async Execution**: Consider using `vim.fn.jobstart()` for non-blocking Claude Code calls
2. **Output Handling**: Parse Claude output and display in a split or floating window
3. **Prompt History**: Track frequently used prompts for quick access
4. **Context Aware**: Pass file type, project context to Claude automatically
