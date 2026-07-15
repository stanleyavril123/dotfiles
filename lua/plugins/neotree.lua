return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		cmd = "Neotree",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
		opts = {
			close_if_last_window = true,
			popup_border_style = "rounded",
			enable_git_status = true,
			enable_diagnostics = true,
			use_popups_for_input = false,
			default_component_configs = {
				indent = {
					with_expanders = true,
					expander_collapsed = "",
					expander_expanded = "",
					expander_highlight = "NeoTreeExpander",
				},
				git_status = {
					symbols = {
						added = "✚",
						modified = "●",
						deleted = "✖",
						renamed = "󰁕",
						untracked = "",
						ignored = "",
						unstaged = "󰄱",
						staged = "",
						conflict = "",
					},
				},
			},
			source_selector = {
				winbar = true,
				statusline = false,
				separator = { left = "", right = "" },
				sources = {
					{ source = "filesystem", display_name = "  Files" },
					{ source = "buffers", display_name = "  Buffers" },
					{ source = "git_status", display_name = "  Git" },
				},
			},
			window = {
				position = "left",
				width = 34,
			},
			filesystem = {
				bind_to_cwd = false,
				follow_current_file = { enabled = true, leave_dirs_open = false },
				group_empty_dirs = true,
				use_libuv_file_watcher = true,
				filtered_items = {
					visible = false,
					hide_dotfiles = false,
					hide_gitignored = true,
					hide_by_name = { ".DS_Store" },
				},
			},
		},
		keys = {
			{ "<C-n>", "<cmd>Neotree toggle reveal<CR>", desc = "Toggle file explorer" },
			{ "<leader>e", "<cmd>Neotree focus reveal<CR>", desc = "Focus file explorer" },
		},
	},
}
