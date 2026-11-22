local map = vim.keymap.set

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Write file" })
map("n", "<leader>q", "<cmd>confirm quit<CR>", { desc = "Quit window" })

map("n", "[d", vim.diagnostic.goto_prev, { desc = "Previous diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Line diagnostics" })

local codex = require("config.codex")
vim.api.nvim_create_user_command("Codex", function(opts)
	if opts.args == "" then
		codex.prompt()
	else
		codex.command(opts.args)
	end
end, { nargs = "*", complete = codex.complete, desc = "Open a Codex prompt or run a Codex command" })
map({ "n", "x" }, "<leader>aa", codex.prompt, { desc = "Ask Codex" })
map("n", "<leader>ac", function()
	codex.command("help")
end, { desc = "Codex commands" })
map("n", "<leader>at", function()
	codex.command("chat")
end, { desc = "Read the current Codex chat" })
map("n", "<leader>ar", codex.review, { desc = "Review Codex changes" })
map({ "n", "x" }, "<leader>ah", codex.history, { desc = "Find or start a Codex chat" })
map("n", "<leader>ax", codex.cancel, { desc = "Stop the current Codex turn" })
