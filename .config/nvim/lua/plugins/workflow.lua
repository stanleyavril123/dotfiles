return {
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {
			preset = "modern",
			delay = 300,
			win = {
				border = "rounded",
				padding = { 1, 2 },
			},
		},
	},
	-- Collects workspace errors so diagnostics can be reviewed or shared with an agent.
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		opts = {
			focus = true,
			warn_no_results = false,
		},
		keys = {
			{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Workspace diagnostics" },
			{ "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics" },
			{ "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix list" },
			{ "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Location list" },
		},
	},
	-- Provides repeatable project commands for builds, tests, and agent verification.
	{
		"stevearc/overseer.nvim",
		branch = "nvim-0.7",
		cmd = { "OverseerRun", "OverseerToggle", "OverseerRunLast" },
		opts = {
			task_list = {
				direction = "bottom",
				min_height = 12,
				max_height = 20,
			},
		},
		keys = {
			{ "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task" },
			{ "<leader>rl", "<cmd>OverseerRunLast<cr>", desc = "Run last task" },
			{ "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Toggle task list" },
		},
	},
}
