return {
	{
		"williamboman/mason.nvim",
		version = "^1.0.0",
		config = function()
			require("mason").setup({
				ui = {
					border = "rounded",
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},

	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
		},
		config = function()
			local lspconfig = require("lspconfig")
			local cmp_nvim_lsp = require("cmp_nvim_lsp")

			vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "rounded" })
			vim.lsp.handlers["textDocument/signatureHelp"] =
				vim.lsp.with(vim.lsp.handlers.signature_help, { border = "rounded" })

			local capabilities = cmp_nvim_lsp.default_capabilities()

			local function map(bufnr, mode, lhs, rhs, desc)
				vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
			end

			local function on_attach(_, bufnr)
				map(bufnr, "n", "gr", "<cmd>Telescope lsp_references<CR>", "Show LSP references")
				map(bufnr, "n", "gD", vim.lsp.buf.declaration, "Go to declaration")
				map(bufnr, "n", "gd", "<cmd>Telescope lsp_definitions<CR>", "Show LSP definitions")
				map(bufnr, "n", "gi", "<cmd>Telescope lsp_implementations<CR>", "Show LSP implementations")
				map(bufnr, "n", "gt", "<cmd>Telescope lsp_type_definitions<CR>", "Show LSP type definitions")
				map(bufnr, { "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code actions")
				map(bufnr, "n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
				map(bufnr, "n", "K", vim.lsp.buf.hover, "Show documentation")
				map(bufnr, "n", "<leader>rs", "<cmd>LspRestart<CR>", "Restart LSP")
			end

			local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
			for type, icon in pairs(signs) do
				local hl = "DiagnosticSign" .. type
				vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
			end

			local servers = {
				lua_ls = {
					settings = {
						Lua = {
							diagnostics = { globals = { "vim" } },
							completion = { callSnippet = "Replace" },
						},
					},
				},
				ts_ls = {
					root_dir = lspconfig.util.root_pattern("package.json", "tsconfig.json", "jsconfig.json", ".git"),
				},
				angularls = {
					root_dir = lspconfig.util.root_pattern("angular.json", "project.json"),
				},
				html = {},
				cssls = {},
				eslint = {},
				pyright = {},
				gopls = {},
				clangd = {},
				jdtls = {},
			}

			for server, config in pairs(servers) do
				config.capabilities = capabilities
				config.on_attach = on_attach
				lspconfig[server].setup(config)
			end
		end,
	},
}
