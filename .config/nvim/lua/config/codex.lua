local rpc = require("config.codex_rpc")
local review = require("config.codex_review")
local controls = require("config.codex_controls")

local M = {}
local projects, runs, loaded = {}, {}, {}
local threads = {}
local client

local function present(value)
	return value ~= nil and value ~= vim.NIL
end

local function tell(message)
	vim.notify(message, vim.log.levels.WARN, { title = "Codex" })
end

local function project()
	local file = vim.api.nvim_buf_get_name(0)
	local cwd = vim.fn.getcwd()
	local root = vim.fs.root(vim.bo.buftype == "" and file ~= "" and file or cwd, ".git") or cwd
	root = vim.uv.fs_realpath(root) or root
	if not projects[root] then
		local dir = vim.fn.stdpath("state") .. "/codex-neovim"
		local state_file = dir .. "/" .. vim.fn.sha256(root)
		local saved = vim.fn.filereadable(state_file) == 1 and vim.fn.readfile(state_file, "", 4) or {}
		projects[root] = {
			root = root,
			state_dir = dir,
			state_file = state_file,
			thread = controls.text(saved[1]),
			model = controls.text(saved[2]),
			effort = controls.text(saved[3]),
			title = controls.text(saved[4]),
		}
	end
	return projects[root]
end

local function save(state)
	if pcall(vim.fn.mkdir, state.state_dir, "p", 448) then
		pcall(vim.fn.writefile, { state.thread or "", state.model or "", state.effort or "", state.title or "" }, state.state_file)
	end
end

local function remember(state, thread, title)
	state.title = title or (state.thread == thread and state.title or nil)
	state.thread = thread
	save(state)
end

local function remember_metadata(thread, result)
	local info = threads[thread.id] or {}
	info.model = controls.text(result.model) or controls.text(thread.model) or info.model
	info.effort = controls.text(result.reasoningEffort) or controls.text(thread.reasoningEffort) or info.effort
	info.status = thread.status and thread.status.type or info.status
	threads[thread.id] = info
end

local function refresh(run)
	if vim.fn.getcmdwintype() ~= "" then
		return
	end
	local prefix = run.root == "/" and "/" or run.root .. "/"
	local seen = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		local file = vim.api.nvim_buf_get_name(buf)
		if not seen[buf] and vim.bo[buf].buftype == "" and vim.startswith(file, prefix) then
			seen[buf] = true
			vim.cmd.checktime(buf)
		end
	end
end

local function finish(run, status, err)
	if run.state.active ~= run then
		return
	end
	if run.thread and runs[run.thread] == run then
		runs[run.thread] = nil
	end
	run.state.active = nil
	run.state.latest = run
	run.status, run.error = status, err
	vim.fn.timer_stop(run.timer)
	refresh(run)
	vim.cmd.redrawstatus()
	review.completed(run)
end

local function approval(server, event)
	local method, params = event.method, event.params or {}
	if method ~= "item/commandExecution/requestApproval" and method ~= "item/fileChange/requestApproval" then
		server.reply(event.id, nil, "This Neovim client does not support " .. method)
		return
	end
	local label = method == "item/fileChange/requestApproval" and "Codex file change" or "Codex command"
	local details = { label }
	for _, value in ipairs({ params.command or vim.NIL, params.reason or vim.NIL, params.grantRoot or vim.NIL }) do
		if present(value) then
			table.insert(details, value)
		end
	end
	if present(params.networkApprovalContext) then
		table.insert(details, params.networkApprovalContext.host)
	end
	local choices = { "Decline", "Cancel turn" }
	if not present(params.availableDecisions) or vim.tbl_contains(params.availableDecisions, "accept") then
		table.insert(choices, 2, "Approve once")
	end
	local run = runs[params.threadId]
	if run then
		run.waiting_for_approval = (run.waiting_for_approval or 0) + 1
		review.progress(run)
	end
	vim.ui.select(choices, { prompt = table.concat(details, " · ") }, function(choice)
		if run then
			run.waiting_for_approval = run.waiting_for_approval - 1
		end
		local decision = choice == "Approve once" and "accept" or choice == "Decline" and "decline" or "cancel"
		server.reply(event.id, { decision = decision })
	end)
end

local function interrupt(run)
	if not run.turn or run.interrupt_sent then
		return
	end
	run.interrupt_sent = true
	client.request("turn/interrupt", { threadId = run.thread, turnId = run.turn }, function(_, err)
		if err and run.state.active == run then
			run.interrupt_sent = false
			run.cancel = false
			tell(err)
		end
	end)
end

local item_activity = {
	agentMessage = "Writing a reply",
	commandExecution = "Running a command",
	fileChange = "Editing files",
	mcpToolCall = "Using a tool",
	webSearch = "Searching the web",
}

local function on_event(server, event)
	if event.id then
		approval(server, event)
		return
	end
	local params = event.params
	if not params then
		return
	end
	if event.method == "thread/name/updated" then
		for _, state in pairs(projects) do
			if state.thread == params.threadId then
				remember(state, state.thread, controls.title({ name = params.threadName }))
			end
		end
		return
	end
	if event.method == "thread/tokenUsage/updated" then
		local info = threads[params.threadId] or {}
		info.usage = params.tokenUsage
		threads[params.threadId] = info
		return
	end
	local run = runs[params.threadId]
	if not run then
		return
	end
	local turn = params.turn
	local turn_id = params.turnId or (turn and turn.id)
	if run.turn and turn_id and run.turn ~= turn_id then
		return
	end
	if event.method == "turn/started" then
		run.turn = turn.id
		run.activity = "Working"
		if run.cancel then
			interrupt(run)
		end
	elseif event.method == "turn/plan/updated" then
		run.plan = params.plan
	elseif event.method == "turn/diff/updated" then
		run.diff = params.diff
		refresh(run)
	elseif event.method == "item/started" then
		local item = params.item
		if item_activity[item.type] then
			run.activity, run.activity_item = item_activity[item.type], item.id
		end
	elseif event.method == "item/agentMessage/delta" then
		if run.answer_item ~= params.itemId then
			run.answer, run.answer_item = "", params.itemId
			run.activity, run.activity_item = "Writing a reply", params.itemId
		end
		run.answer = run.answer .. params.delta
	elseif event.method == "item/completed" then
		local item = params.item
		if run.activity_item == item.id then
			run.activity, run.activity_item = "Working", nil
		end
		if item.type == "agentMessage" and item.text ~= "" then
			run.answer, run.answer_item = item.text, item.id
		elseif item.type == "fileChange" then
			if item.status == "completed" then
				for _, change in ipairs(item.changes) do
					table.insert(run.changes, change)
				end
			end
			refresh(run)
		elseif item.type == "commandExecution" then
			local status = present(item.exitCode) and ("exit " .. item.exitCode) or item.status
			table.insert(run.commands, ("[%s] %s"):format(status, item.command:gsub("\n", " ")))
		end
	elseif event.method == "turn/completed" then
		for _, item in ipairs(turn.items or {}) do
			if item.type == "agentMessage" and item.text ~= "" then
				run.answer = item.text
			end
		end
		finish(run, turn.status, present(turn.error) and turn.error.message or nil)
	end
end

local function connect()
	if client then
		return client
	end
	local err
	client, err = rpc.connect(on_event, function(message)
		client, loaded = nil, {}
		for _, state in pairs(projects) do
			if state.active then
				finish(state.active, "failed", message)
			end
		end
	end)
	return client, err
end

local function metadata(state, callback)
	local thread = state.thread
	local server, err = connect()
	if not server then
		callback(err)
		return
	end
	server.request("thread/read", { threadId = thread }, function(result, read_error)
		if state.thread ~= thread then
			return
		end
		if not read_error then
			remember_metadata(result.thread, result)
			local title = controls.title(result.thread)
			if title and title ~= state.title then
				remember(state, thread, title)
			end
		end
		callback(read_error)
	end)
end

local function begin(state, prompt)
	local server, err = connect()
	if not server then
		tell(err)
		return
	end
	local run = { state = state, root = state.root, status = "running", answer = "", diff = "", changes = {}, commands = {} }
	run.model, run.effort = state.model, state.effort
	state.active = run
	review.started(run)
	run.timer = vim.fn.timer_start(1000, function()
		refresh(run)
		vim.cmd.redrawstatus()
	end, { ["repeat"] = -1 })
	vim.cmd.redrawstatus()

	local function start_turn(thread)
		if run.cancel then
			finish(run, "interrupted")
			return
		end
		run.thread = thread
		runs[thread] = run
		server.request("turn/start", {
			threadId = thread,
			cwd = state.root,
			model = run.model,
			effort = run.effort,
			input = { { type = "text", text = prompt, text_elements = {} } },
		}, function(result, turn_error)
			if state.active ~= run then
				return
			end
			if turn_error then
				finish(run, "failed", turn_error)
				return
			end
			run.turn = result.turn.id
			local info = threads[thread] or {}
			info.model, info.effort = run.model or info.model, run.effort or info.effort
			threads[thread] = info
			if run.cancel then
				interrupt(run)
			end
		end)
	end

	local function thread_ready(result, thread_error)
		if state.active ~= run then
			return
		end
		if thread_error then
			finish(run, "failed", thread_error)
			return
		end
		local thread = result.thread.id
		loaded[thread] = true
		remember_metadata(result.thread, result)
		local title = controls.title(result.thread) or state.title or vim.fn.strcharpart(prompt:match("[^\n]+") or "", 0, 80)
		remember(state, thread, title)
		run.title = title
		start_turn(thread)
	end

	local thread = state.thread
	if thread and loaded[thread] then
		run.title = state.title
		start_turn(thread)
	else
		local params = { cwd = state.root, sandbox = "workspace-write" }
		if thread then
			params.threadId, params.excludeTurns = thread, true
			server.request("thread/resume", params, thread_ready)
		else
			server.request("thread/start", params, thread_ready)
		end
	end
end

local function context(state)
	local file = vim.api.nvim_buf_get_name(0)
	if vim.bo.buftype ~= "" or file == "" then
		return nil
	end
	local prefix = state.root == "/" and "/" or state.root .. "/"
	local path = vim.startswith(file, prefix) and file:sub(#prefix + 1) or file
	local mode = vim.fn.mode()
	if mode == "v" or mode == "V" or mode == "\22" then
		local first, last = vim.fn.getpos("v"), vim.fn.getpos(".")
		local range = ("%d-%d"):format(math.min(first[2], last[2]), math.max(first[2], last[2]))
		local selected = vim.fn.getregion(first, last, { type = mode, exclusive = vim.o.selection == "exclusive" })
		vim.cmd("normal! \27")
		return path .. ":" .. range, table.concat(selected, "\n"), vim.bo.modified
	end
	return path, nil, vim.bo.modified
end

local function prompt_window(state, path, selection, modified)
	if state.active then
		tell("Codex is already working here. Space a r shows progress, and Space a x stops the turn.")
		return
	end
	local title = "Codex · " .. controls.label(state)
	local footer = "/help" .. (state.model and (" · " .. state.model) or "")
	if path then
		footer = footer .. " · " .. path .. (modified and " · unsaved" or "")
	end
	local buf, win = review.float({ "" }, { title = title, focus = true, height = 4 })
	local width = vim.api.nvim_win_get_width(win)
	vim.api.nvim_win_set_config(win, { footer = " " .. vim.fn.strcharpart(footer, 0, math.max(1, width - 3)) .. " " })
	if state.thread and not state.title then
		metadata(state, function()
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_set_config(win, { title = " Codex · " .. controls.label(state) .. " " })
			end
		end)
	end
	-- Grow the empty prompt before entering insert mode, so multiline input has space.
	vim.api.nvim_win_set_height(win, math.min(4, math.max(1, vim.o.lines - 6)))
	local function close()
		vim.cmd.stopinsert()
		vim.api.nvim_win_close(win, true)
	end
	vim.keymap.set({ "i", "n" }, "<Esc>", close, { buffer = buf, nowait = true })
	vim.keymap.set({ "i", "n" }, "<CR>", function()
		local prompt = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
		if prompt == "" then
			return
		end
		close()
		if prompt:match("^/[%w%-]+[%s]*$") or prompt:match("^/[%w%-]+[ \t]+[^\n]+$") then
			vim.schedule(function()
				M.command(prompt, state, { path, selection, modified })
			end)
			return
		end
		if path then
			prompt = prompt .. "\n\nEditor context: " .. path
			if modified then
				prompt = prompt .. "\nThis file has unsaved edits in Neovim. Preserve those edits and call out any overlap."
			end
			if selection then
				prompt = prompt .. "\nSelected text:\n" .. selection
			end
		end
		begin(state, prompt)
	end, { buffer = buf, nowait = true })
	vim.keymap.set("i", "<C-j>", "<CR>", { buffer = buf })
	vim.cmd.startinsert()
end

function M.prompt()
	local state = project()
	prompt_window(state, context(state))
end

function M.review()
	local state = project()
	local run = state.active or state.latest
	if not run then
		tell("No Codex turn to review in this project yet.")
		return
	end
	review.open(run, function(hunk)
		if run.thread and run.thread ~= state.thread and not state.active then
			remember(state, run.thread, run.title)
		end
		prompt_window(state, hunk and (hunk.path .. ":" .. hunk.line) or nil)
	end)
end

function M.cancel()
	local run = project().active
	if run then
		run.cancel = true
		interrupt(run)
	end
end

function M.status()
	for _, state in pairs(projects) do
		if state.active then
			return state.active.cancel and "Codex stopping" or "Codex working"
		end
	end
	return ""
end

local function pick(title, choices, select)
	local ok, pickers = pcall(require, "telescope.pickers")
	if not ok then
		vim.ui.select(choices, { prompt = title, format_item = function(choice)
			return choice.label
		end }, select)
		return
	end
	local actions = require("telescope.actions")
	pickers.new({}, {
		prompt_title = title,
		finder = require("telescope.finders").new_table({
			results = choices,
			entry_maker = function(choice)
				return { value = choice, display = choice.label, ordinal = choice.label }
			end,
		}),
		sorter = require("telescope.config").values.generic_sorter({}),
		attach_mappings = function(buf)
			actions.select_default:replace(function()
				local choice = require("telescope.actions.state").get_selected_entry()
				actions.close(buf)
				if choice then
					vim.schedule(function() select(choice.value) end)
				end
			end)
			return true
		end,
	}):find()
end

function M.history()
	local state = project()
	if state.active then
		tell("Finish or stop the active turn before switching chats.")
		return
	end
	local path, selection, modified = context(state)
	local server, err = connect()
	if not server then
		tell(err)
		return
	end
	local function page(cursor)
		local params = {
			cwd = state.root,
			sortKey = "updated_at",
			sourceKinds = { "appServer", "cli", "vscode" },
			limit = 75,
			cursor = cursor,
		}
		server.request("thread/list", params, function(result, list_error)
			if list_error then
				tell(list_error)
				return
			end
			local choices = { { label = "New chat" } }
			for _, thread in ipairs(result.data) do
				local title = controls.title(thread) or "Untitled chat"
				remember_metadata(thread, {})
				local day = thread.updatedAt and os.date("%Y-%m-%d", thread.updatedAt) or ""
				table.insert(choices, {
					id = thread.id,
					title = title,
					label = ("%s%s  %s · %s"):format(state.thread == thread.id and "● " or "", day, title, thread.id:sub(-6)),
				})
			end
			if present(result.nextCursor) then
				table.insert(choices, { label = "Older chats…", cursor = result.nextCursor })
			end
			pick("Codex chats", choices, function(choice)
				if not choice or state.active then
					return
				end
				if choice.cursor then
					page(choice.cursor)
					return
				end
				remember(state, choice.id, choice.title)
				prompt_window(state, path, selection, modified)
			end)
		end)
	end
	page(nil)
end

local function choose_model(state)
	local server, err = connect()
	if not server then
		tell(err)
		return
	end
	controls.models(server, state, pick, function(model, effort)
		state.model, state.effort = model, effort
		save(state)
		vim.notify("Next Codex turn uses " .. model .. (effort and (" · " .. effort) or ""))
	end, tell)
end

local function show_status(state)
	local function show(config, err)
		local info = threads[state.thread] or {}
		local model = info.model or controls.text(config.model) or "Codex default"
		local effort = info.effort or controls.text(config.model_reasoning_effort)
		local run = state.active
		local lines = {
			controls.label(state),
			"Session ID  " .. (state.thread or "Will be assigned on send"),
			"Project     " .. state.root,
			"State       " .. (run and (run.cancel and "Stopping" or "Working") or (info.status == "active" and "Active in Codex" or "Idle")),
			"Model       " .. model .. (effort and (" · " .. effort) or ""),
		}
		if state.model then
			table.insert(lines, "Next turn   " .. state.model .. (state.effort and (" · " .. state.effort) or ""))
		end
		if info.usage then
			table.insert(lines, "Last turn   " .. info.usage.last.totalTokens .. " tokens")
			if present(info.usage.modelContextWindow) then
				table.insert(lines, "Context     " .. info.usage.modelContextWindow .. " tokens")
			end
		end
		if err then
			vim.list_extend(lines, vim.split(err, "\n", { plain = true }))
		end
		controls.readonly(lines, "Codex status", { height = 14 })
	end
	if state.thread then
		metadata(state, function(err)
			show({}, err)
		end)
		return
	end
	local server, err = connect()
	if not server then
		show({}, err)
		return
	end
	server.request("config/read", { cwd = state.root }, function(result, config_error)
		show(result and result.config or {}, config_error)
	end)
end

local function transcript(state)
	local thread = state.thread
	if not thread then
		tell("Send a prompt or select a chat to see its transcript.")
		return
	end
	local server, err = connect()
	if not server then
		tell(err)
		return
	end
	controls.transcript(server, state, thread, tell, function()
		if state.thread == thread then
			prompt_window(state, context(state))
		end
	end)
end

local function rename(state, name)
	local thread = state.thread
	if not thread then
		tell("Send a prompt first to create a chat you can rename.")
		return
	end
	local function submit(value)
		local title = value and controls.title({ name = value })
		if not title then
			return
		end
		local server, err = connect()
		if not server then
			tell(err)
			return
		end
		server.request("thread/name/set", { threadId = thread, name = title }, function(_, rename_error)
			if rename_error then
				tell(rename_error)
			elseif state.thread == thread then
				remember(state, thread, title)
			end
		end)
	end
	if name ~= "" then
		submit(name)
	else
		vim.ui.input({ prompt = "Chat name", default = state.title }, submit)
	end
end

local commands = {
	{ name = "model", description = "Choose a model and reasoning effort" },
	{ name = "status", description = "Show session ID, model, and turn status" },
	{ name = "chat", description = "Read this chat’s prompts and answers" },
	{ name = "history", description = "Find a previous chat" },
	{ name = "new", description = "Start a fresh chat" },
	{ name = "rename", description = "Name the current chat" },
	{ name = "review", description = "Review the latest edits" },
	{ name = "stop", description = "Stop the current turn" },
}

function M.command(input, state, editor_context)
	state = state or project()
	local name, args = vim.trim(input):match("^/?([%w%-]*)%s*(.*)$")
	if name == "model" then
		choose_model(state)
	elseif name == "status" then
		show_status(state)
	elseif name == "chat" or name == "transcript" then
		transcript(state)
	elseif name == "history" then
		M.history()
	elseif name == "new" then
		if state.active then
			tell("Finish or stop the active turn before starting a new chat.")
			return
		end
		remember(state, nil)
		if editor_context then
			prompt_window(state, unpack(editor_context, 1, 3))
		else
			prompt_window(state, context(state))
		end
	elseif name == "rename" then
		rename(state, args)
	elseif name == "review" then
		M.review()
	elseif name == "stop" then
		M.cancel()
	else
		if name ~= "help" and name ~= "" then
			tell("Unknown Codex command: " .. (name or input))
		end
		local choices = vim.tbl_map(function(command)
			return { name = command.name, label = "/" .. command.name .. "   " .. command.description }
		end, commands)
		pick("Codex commands", choices, function(choice)
			if choice then
				M.command(choice.name, state, editor_context)
			end
		end)
	end
end

function M.complete(lead)
	local matches = {}
	for _, command in ipairs(commands) do
		if vim.startswith(command.name, lead) then
			table.insert(matches, command.name)
		end
	end
	return matches
end

return M
