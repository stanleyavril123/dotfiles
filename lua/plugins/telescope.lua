return {
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.8",
		cmd = "Telescope",
		keys = {
			{ "<C-p>", "<cmd>Telescope find_files<CR>", desc = "Find files" },
			{ "<leader>sf", "<cmd>Telescope find_files<CR>", desc = "Find files" },
			{ "<leader>sg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
			{ "<leader>sw", "<cmd>Telescope grep_string<CR>", desc = "Grep word" },
			{ "<leader>sb", "<cmd>Telescope current_buffer_fuzzy_find<CR>", desc = "Search current file" },
			{ "<leader>st", "<cmd>Telescope treesitter<CR>", desc = "File symbols" },
			{ "<leader>sd", "<cmd>Telescope diagnostics<CR>", desc = "Workspace diagnostics" },
			{ "<leader>sq", "<cmd>Telescope quickfix<CR>", desc = "Quickfix list" },
			{ "<leader>gc", "<cmd>Telescope git_status<CR>", desc = "Changed Git files" },
			{ "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
			{ "<leader>fr", "<cmd>Telescope resume<CR>", desc = "Resume picker" },
		},
		dependencies = {
			"nvim-lua/plenary.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		},
		config = function()
			local telescope = require("telescope")

			telescope.setup({
				defaults = {
					prompt_prefix = "   ",
					selection_caret = "  ",
					entry_prefix = "  ",
					sorting_strategy = "ascending",
					dynamic_preview_title = true,
					layout_strategy = "horizontal",
					layout_config = {
						prompt_position = "top",
						width = 0.88,
						height = 0.82,
						preview_width = 0.55,
					},
					borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
					file_ignore_patterns = { "venv/", "%.pyc", "__pycache__/", "node_modules/", "%.git/" },
					path_display = { "smart" },
				},
				extensions = {
					fzf = {
						fuzzy = true,
						override_generic_sorter = true,
						override_file_sorter = true,
						case_mode = "smart_case",
					},
				},
			})
			pcall(telescope.load_extension, "fzf")
		end,
	},
}
