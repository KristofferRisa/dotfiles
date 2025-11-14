return {
	"nvim-tree/nvim-tree.lua",
	dependencies = {
		"nvim-tree/nvim-web-devicons", -- for file icons
	},
	opts = {
		filters = {
			dotfiles = false, -- Show hidden files/folders
			git_ignored = false, -- Show git-ignored files
			custom = {}, -- Don't hide any custom patterns
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
				},
				glyphs = {
					default = "",
					symlink = "",
					folder = {
						arrow_closed = "",
						arrow_open = "",
						default = "",
						open = "",
						empty = "",
						empty_open = "",
						symlink = "",
						symlink_open = "",
					},
				},
			},
		},
		actions = {
			open_file = {
				quit_on_open = false,
			},
		},
		git = {
			enable = true,
			ignore = false, -- Show git-ignored files
		},
	},
}
