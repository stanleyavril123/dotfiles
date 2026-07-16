return {
	{
		"catppuccin/nvim",
		name = "catppuccin",
		priority = 1000,
		config = function()
			vim.opt.termguicolors = true
			vim.opt.background = "dark"

			require("catppuccin").setup({
				flavour = "mocha",
				transparent_background = true,
				integrations = {
					alpha = true,
					cmp = true,
					gitsigns = true,
					indent_blankline = { enabled = true, scope_color = "mauve" },
					mason = true,
					native_lsp = { enabled = true },
					neotree = true,
					telescope = { enabled = true },
					treesitter = true,
					trouble = true,
					which_key = true,
				},
				custom_highlights = function(cp)
					return {
						CursorLine = { bg = cp.surface0 },
						CursorLineNr = { fg = cp.peach, bold = true },
						FloatBorder = { fg = cp.surface1, bg = cp.mantle },
						LineNr = { fg = cp.overlay0 },
						NormalFloat = { bg = cp.mantle },
						Pmenu = { bg = cp.mantle },
						PmenuSel = { bg = cp.surface1, bold = true },
						Visual = { bg = cp.surface1 },
						WinSeparator = { fg = cp.surface0, bg = "NONE" },
						TelescopeBorder = { fg = cp.surface1, bg = cp.mantle },
						TelescopeNormal = { bg = cp.mantle },
						TelescopePreviewTitle = { fg = cp.crust, bg = cp.green, bold = true },
						TelescopePromptBorder = { fg = cp.blue, bg = cp.mantle },
						TelescopePromptTitle = { fg = cp.crust, bg = cp.blue, bold = true },
						TelescopeResultsTitle = { fg = cp.crust, bg = cp.mauve, bold = true },
					}
				end,
			})

			vim.cmd.colorscheme("catppuccin")
		end,
	},
}
