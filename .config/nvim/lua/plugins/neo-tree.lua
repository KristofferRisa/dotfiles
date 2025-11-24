return {
  "nvim-tree/nvim-tree.lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons", -- for file icons
  },
  opts = {
    filters = {
      dotfiles = true, -- Show hidden files/folders
      git_ignored = true, -- Show git-ignored files
      -- custom = { "^.git$" }, -- Hide .git folder specifically
    },
    view = {
      width = 30,
      side = "left",
    },
    renderer = {
      icons = {
        show = {
          file = true,
          folder = true,
          folder_arrow = true,
          git = true,
          hidden = true,
        },
      },
    },
    actions = {
      open_file = {
        quit_on_open = false,
      },
    },
  },
}
