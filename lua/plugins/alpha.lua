return {
	{
		"goolord/alpha-nvim",
		event = "VimEnter",
		config = function()
			local alpha = require("alpha")
			local dashboard = require("alpha.themes.dashboard")
			local stats = require("lazy").stats()
			local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":~")

			dashboard.section.header.val = {
				[[                                  __]],
				[[     ___     ___    ___   __  __ /\_\    ___ ___]],
				[[    / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\]],
				[[   /\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \]],
				[[   \ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
				[[    \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]],
			}
			dashboard.section.header.opts.hl = "Type"

			dashboard.section.buttons.val = {
				dashboard.button("f", "  Find file", "<cmd>Telescope find_files<CR>"),
				dashboard.button("g", "  Search project", "<cmd>Telescope live_grep<CR>"),
				dashboard.button("r", "  Recent files", "<cmd>Telescope oldfiles<CR>"),
				dashboard.button("e", "󰙅  File explorer", "<cmd>Neotree reveal<CR>"),
				dashboard.button("n", "  New file", "<cmd>ene <BAR> startinsert<CR>"),
				dashboard.button("l", "󰒲  Plugin manager", "<cmd>Lazy<CR>"),
				dashboard.button("q", "  Quit", "<cmd>qa<CR>"),
			}

			dashboard.section.footer.val = {
				cwd,
				string.format("%d plugins  |  startup %.0f ms", stats.count, stats.startuptime),
			}
			dashboard.section.footer.opts.hl = "Comment"

			dashboard.config.layout = {
				{ type = "padding", val = 5 },
				dashboard.section.header,
				{ type = "padding", val = 2 },
				dashboard.section.buttons,
				{ type = "padding", val = 2 },
				dashboard.section.footer,
			}
			dashboard.config.opts.noautocmd = true
			alpha.setup(dashboard.config)
		end,
	},
}
