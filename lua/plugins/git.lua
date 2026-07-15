return {
	{
		"lewis6991/gitsigns.nvim",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			current_line_blame = false,
			current_line_blame_opts = { delay = 500 },
		},
		keys = {
			{ "]h", "<cmd>Gitsigns next_hunk<CR>", desc = "Next Git hunk" },
			{ "[h", "<cmd>Gitsigns prev_hunk<CR>", desc = "Previous Git hunk" },
			{ "<leader>gb", "<cmd>Gitsigns blame_line<CR>", desc = "Git blame line" },
			{ "<leader>gB", "<cmd>Gitsigns toggle_current_line_blame<CR>", desc = "Toggle Git blame" },
			{ "<leader>gp", "<cmd>Gitsigns preview_hunk<CR>", desc = "Preview hunk" },
			{ "<leader>gr", "<cmd>Gitsigns reset_hunk<CR>", desc = "Reset hunk" },
			{ "<leader>gs", "<cmd>Gitsigns stage_hunk<CR>", desc = "Stage hunk" },
		},
	},
	{
		"NeogitOrg/neogit",
		cmd = "Neogit",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
		},
		config = true,
		keys = {
			{ "<leader>gg", "<cmd>Neogit<CR>", desc = "Neogit" },
		},
	},
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewFileHistory" },
		keys = {
			{ "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Open Diffview" },
			{ "<leader>gh", "<cmd>DiffviewFileHistory %<CR>", desc = "File history" },
		},
	},
}
