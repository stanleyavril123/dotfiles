return {
	{
		"akinsho/bufferline.nvim",
		version = "*",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		opts = {
			options = {
				diagnostics = "nvim_lsp",
				diagnostics_indicator = function(count, level)
					local icon = level:match("error") and " " or " "
					return " " .. icon .. count
				end,
				always_show_bufferline = false,
				separator_style = "thin",
				show_buffer_close_icons = false,
				show_close_icon = false,
				color_icons = true,
				offsets = {
					{
						filetype = "neo-tree",
						text = "EXPLORER",
						text_align = "left",
						separator = true,
					},
				},
			},
		},
		keys = {
			{ "<S-h>", "<cmd>BufferLineCyclePrev<CR>", desc = "Previous buffer" },
			{ "<S-l>", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
			{ "<leader>bp", "<cmd>BufferLinePick<CR>", desc = "Pick buffer" },
			{ "<leader>bd", "<cmd>confirm bdelete<CR>", desc = "Delete buffer" },
		},
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			indent = { char = "│" },
			scope = {
				enabled = true,
				char = "│",
				show_start = false,
				show_end = false,
			},
			exclude = {
				filetypes = { "alpha", "dashboard", "help", "lazy", "mason", "neo-tree", "notify", "trouble" },
			},
		},
	},
}
