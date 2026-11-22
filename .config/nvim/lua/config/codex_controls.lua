local review = require("config.codex_review")
local M = {}
local speakers = vim.api.nvim_create_namespace("codex_speakers")

function M.text(value)
	return type(value) == "string" and value ~= "" and value or nil
end

function M.title(thread)
	local name = M.text(thread.name) or M.text(thread.preview)
	return name and M.text(vim.trim(name:gsub("%s+", " "))) or nil
end

function M.label(state)
	if not state.thread then
		return "New chat"
	end
	return "Chat " .. state.thread:sub(-6) .. (state.title and (" · " .. state.title) or "")
end

function M.readonly(lines, title, opts)
	opts = opts or {}
	local buf, win = review.float(lines, { title = title, focus = true, height = opts.height or 22, width = opts.width or 100 })
	vim.bo[buf].modifiable = false
	local function close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, close, { buffer = buf, nowait = true })
	end
	return buf, win, close
end

function M.models(server, state, pick, save, tell)
	local choices = {}
	local function load(cursor)
		server.request("model/list", { includeHidden = false, limit = 100, cursor = cursor }, function(result, err)
			if err then
				tell(err)
				return
			end
			for _, model in ipairs(result.data) do
				local id = model.model or model.id
				local title = M.text(model.displayName) or id
				table.insert(choices, {
					label = (state.model == id and "● " or "") .. title
						.. (title ~= id and (" · " .. id) or "")
						.. (model.isDefault and " (default)" or ""),
					model = model,
					id = id,
				})
			end
			if M.text(result.nextCursor) then
				load(result.nextCursor)
				return
			end
			if #choices == 0 then
				tell("Codex returned no available models.")
				return
			end
			pick("Codex models", choices, function(choice)
				if not choice then
					return
				end
				local model = choice.model
				local options = model.supportedReasoningEfforts or {}
				if #options <= 1 then
					save(choice.id, M.text(model.defaultReasoningEffort) or (options[1] or {}).reasoningEffort)
					return
				end
				vim.ui.select(options, {
					prompt = "Reasoning effort",
					format_item = function(option)
						return option.reasoningEffort
							.. (option.reasoningEffort == model.defaultReasoningEffort and " (default)" or "")
							.. (M.text(option.description) and (" · " .. option.description) or "")
					end,
				}, function(option)
					if option then
						save(choice.id, option.reasoningEffort)
					end
				end)
			end)
		end)
	end
	load(nil)
end

local function add_message(lines, heading, content)
	table.insert(lines, heading)
	vim.list_extend(lines, vim.split(content, "\n", { plain = true }))
	table.insert(lines, "")
end

local function render(turns, header)
	local lines, labels, replies = { header, "" }, {}, {}
	for index = #turns, 1, -1 do
		for _, item in ipairs(turns[index].items or {}) do
			if item.type == "userMessage" then
				local parts = {}
				for _, input in ipairs(item.content) do
					table.insert(parts, input.type == "text" and input.text or "[" .. input.type .. "]")
				end
				if #parts > 0 then
					labels[#lines] = "Title"
					add_message(lines, "You", table.concat(parts, "\n"))
				end
			elseif item.type == "agentMessage" and M.text(item.text) then
				local first = #lines + 2
				labels[#lines] = "DiagnosticInfo"
				add_message(lines, "Codex", item.text)
				table.insert(replies, { first, #lines - 1 })
			end
		end
	end
	return lines, labels, replies
end

function M.transcript(server, state, thread, tell, continue)
	local next_cursor, buf, win, close
	local turns, rendered_rows = {}, 0
	local pending = false

	local function load(cursor)
		if pending then
			return
		end
		pending = true
		server.request("thread/turns/list", {
			threadId = thread,
			itemsView = "full",
			sortDirection = "desc",
			limit = 12,
			cursor = cursor,
		}, function(result, err)
			pending = false
			if err then
				tell(err)
				return
			end
			if state.thread ~= thread or (win and not vim.api.nvim_win_is_valid(win)) then
				return
			end
			next_cursor = M.text(result.nextCursor)
			vim.list_extend(turns, result.data)
			local header = "r  Reply    q  Close" .. (next_cursor and "    o  Load older turns" or "")
			local lines, labels, replies = render(turns, header)
			local new_rows = #lines - rendered_rows
			rendered_rows = #lines
			if #lines == 2 then
				lines[3] = "No saved messages in this chat yet."
			end
			if buf then
				vim.bo[buf].modifiable = true
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.bo[buf].modifiable = false
			else
				buf, win, close = M.readonly(lines, "Codex · " .. M.label(state))
				vim.keymap.set("n", "o", function()
					if next_cursor then
						load(next_cursor)
					end
				end, { buffer = buf, nowait = true })
				vim.keymap.set("n", "r", function()
					close()
					continue()
				end, { buffer = buf, nowait = true })
			end
			vim.api.nvim_buf_clear_namespace(buf, speakers, 0, -1)
			for row, highlight in pairs(labels) do
				vim.api.nvim_buf_add_highlight(buf, speakers, highlight, row, 0, -1)
			end
			review.markdown(buf, win, replies)
			local row = cursor and math.max(3, new_rows + 2) or #lines
			vim.api.nvim_win_set_cursor(win, { math.min(row, #lines), 0 })
		end)
	end
	load(nil)
end

return M
