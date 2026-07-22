return {
	{
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown" },
		cmd = { "RenderMarkdown" },
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		keys = {
			{
				"<leader>mp",
				"<cmd>RenderMarkdown buf_toggle<CR>",
				desc = "Toggle Markdown preview",
				ft = "markdown",
			},
		},
		opts = {
			completions = {
				lsp = { enabled = true },
			},
		},
	},
}
