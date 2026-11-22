local M = {}

local function diff_path(header)
	if header == "/dev/null" then
		return nil
	end
	if header:sub(1, 1) == '"' and header:sub(-1) == '"' then
		header = header:sub(2, -2):gsub("\\([0-7][0-7][0-7])", function(octal)
			return string.char(tonumber(octal, 8))
		end):gsub('\\(["\\])', "%1")
	end
	return header:gsub("^[ab]/", "")
end

local function entries(run)
	local hunks, files = {}, {}
	local old, new, hunk
	for _, line in ipairs(vim.split(run.diff, "\n", { plain = true })) do
		if line:match("^diff %-%-git ") then
			old, new, hunk = nil, nil, nil
		elseif not hunk and line:sub(1, 4) == "--- " then
			old = diff_path(line:sub(5):gsub("\t$", ""))
		elseif not hunk and line:sub(1, 4) == "+++ " then
			new = diff_path(line:sub(5):gsub("\t$", ""))
		elseif line:match("^@@ ") and (new or old) then
			local start = tonumber(line:match("%+(%d+)")) or 1
			hunk = { path = new or old, line = math.max(1, start), deleted = not new, header = line, lines = {} }
			files[hunk.path] = true
			table.insert(hunks, hunk)
		elseif hunk then
			table.insert(hunk.lines, line)
		end
	end
	local prefix = run.root == "/" and "/" or run.root .. "/"
	for _, change in ipairs(run.changes) do
		local path = change.kind.move_path
		if type(path) ~= "string" then
			path = change.path
		end
		if vim.startswith(path, prefix) then
			path = path:sub(#prefix + 1)
		end
		if not files[path] then
			files[path] = true
			table.insert(hunks, {
				path = path,
				line = 1,
				deleted = change.kind.type == "delete",
				header = change.kind.type,
				lines = vim.split(change.diff, "\n", { plain = true }),
			})
		end
	end
	return hunks, vim.tbl_count(files)
end

function M.float(lines, opts)
	local width = math.min(opts.width or 76, math.max(1, vim.o.columns - 4))
	local height = math.min(#lines, opts.height or 13, math.max(1, vim.o.lines - 6))
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local win = vim.api.nvim_open_win(buf, opts.focus == true, {
		relative = "editor",
		width = width,
		height = height,
		row = opts.bottom and math.max(0, vim.o.lines - height - 4)
			or math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = opts.bottom and math.max(0, vim.o.columns - width - 3)
			or math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		zindex = opts.zindex,
		title = " " .. opts.title .. " ",
		focusable = opts.focus == true,
		noautocmd = true,
	})
	vim.wo[win].wrap = true
	return buf, win
end

function M.markdown(buf, win, ranges)
	if #ranges == 0 then
		return
	end
	local ok, parser = pcall(vim.treesitter.get_parser, buf, "markdown")
	if not ok or not parser then
		return
	end
	local regions = {}
	for _, range in ipairs(ranges) do
		local last = vim.api.nvim_buf_get_lines(buf, range[2] - 1, range[2], false)[1]
		table.insert(regions, { { range[1] - 1, 0, range[2] - 1, #last } })
	end
	parser:set_included_regions(regions)
	if not vim.b[buf].codex_markdown then
		vim.treesitter.start(buf, "markdown")
		vim.b[buf].codex_markdown = true
	end
	vim.wo[win].conceallevel = 2
	vim.wo[win].concealcursor = "nvic"
end

local function summary(run)
	local lines = {}
	if run.error then
		vim.list_extend(lines, vim.split(run.error, "\n", { plain = true }))
	end
	local reply_start
	if run.answer ~= "" then
		reply_start = #lines + 1
		vim.list_extend(lines, vim.split(run.answer, "\n", { plain = true, trimempty = true }))
	end
	if #lines == 0 then
		lines[1] = "No summary from Codex."
	end
	return lines, reply_start
end

local notice, activity
local active = {}
local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function close(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

local function elapsed(run)
	return math.floor((vim.uv.hrtime() - run.started_at) / 1e9)
end

local function progress_detail(plan)
	if not plan or #plan == 0 then
		return "Space a r  Review   ·   Space a x  Stop"
	end
	local done, current = 0, nil
	for _, step in ipairs(plan) do
		if step.status == "completed" then
			done = done + 1
		elseif step.status == "inProgress" then
			current = step.step:gsub("%s+", " ")
		end
	end
	local filled = math.floor(8 * done / #plan)
	local bar = string.rep("━", filled) .. string.rep("─", 8 - filled)
	return ("%s  %d/%d%s"):format(bar, done, #plan, current and ("  " .. current) or " steps")
end

function M.progress(run)
	if active[#active] ~= run or vim.fn.getcmdwintype() ~= "" or (notice and vim.api.nvim_win_is_valid(notice)) then
		return
	end
	local seconds = elapsed(run)
	local frame = math.floor((vim.uv.hrtime() - run.started_at) / 1.2e8)
	local stage = run.cancel and "Stopping"
		or (run.waiting_for_approval or 0) > 0 and "Waiting for approval"
		or run.activity or "Starting Codex"
	local lines = {
		("%s %s · %d:%02d"):format(spinner[frame % #spinner + 1], stage, math.floor(seconds / 60), seconds % 60),
		progress_detail(run.plan),
	}
	local tab = vim.api.nvim_get_current_tabpage()
	if not activity or not vim.api.nvim_win_is_valid(activity.win)
		or activity.tab ~= tab or activity.columns ~= vim.o.columns or activity.lines ~= vim.o.lines
	then
		close(activity and activity.win)
		local buf, win = M.float(lines, { title = "Codex", bottom = true, width = 45, height = 2, zindex = 40 })
		vim.wo[win].wrap = false
		vim.wo[win].winhighlight = "FloatBorder:DiagnosticInfo,FloatTitle:Title"
		activity = { buf = buf, win = win, tab = tab, columns = vim.o.columns, lines = vim.o.lines }
	else
		vim.api.nvim_buf_set_lines(activity.buf, 0, -1, false, lines)
	end
end

function M.started(run)
	run.started_at = vim.uv.hrtime()
	table.insert(active, run)
	close(notice)
	M.progress(run)
	run.progress_timer = vim.fn.timer_start(120, function()
		M.progress(run)
	end, { ["repeat"] = -1 })
end

function M.completed(run)
	if run.progress_timer then
		vim.fn.timer_stop(run.progress_timer)
		for index, running in ipairs(active) do
			if running == run then
				table.remove(active, index)
				break
			end
		end
	end
	close(activity and activity.win)
	close(notice)
	local _, files = entries(run)
	local outcome = ({ completed = "Done", interrupted = "Stopped", failed = "Failed" })[run.status] or run.status
	local timing = run.started_at and (" · %ds"):format(elapsed(run)) or ""
	local lines = { ("%s · %d changed %s%s"):format(outcome, files, files == 1 and "file" or "files", timing) }
	local reply, first = summary(run)
	local preview_start
	for index, line in ipairs(reply) do
		if vim.trim(line) ~= "" then
			table.insert(lines, line)
			if first and index >= first and not preview_start then
				preview_start = #lines
			end
		end
		if #lines == 3 then
			break
		end
	end
	local preview_end = #lines
	table.insert(lines, "Space a r  Review")
	local title = run.thread and ("Codex · Chat " .. run.thread:sub(-6)) or "Codex"
	local buf, win = M.float(lines, { title = title, bottom = true, height = 4, zindex = 40 })
	vim.wo[win].wrap = false
	local color = ({ completed = "DiagnosticOk", interrupted = "DiagnosticWarn", failed = "DiagnosticError" })[run.status]
	vim.wo[win].winhighlight = "FloatBorder:" .. (color or "FloatBorder") .. ",FloatTitle:Title"
	if preview_start then
		M.markdown(buf, win, { { preview_start, preview_end } })
	end
	notice = win
	vim.defer_fn(function()
		close(win)
	end, 10000)
end

function M.open(run, follow_up)
	local hunks, files = entries(run)
	local lines = { "Enter  Jump    d  Diff    r  Revise    q  Close", "" }
	local by_row = {}
	for _, hunk in ipairs(hunks) do
		table.insert(lines, ("  %s:%d  %s"):format(hunk.path, hunk.line, hunk.header))
		by_row[#lines] = hunk
	end
	if #hunks == 0 then
		table.insert(lines, "No changes reported yet. Space g d opens the working-tree diff.")
	end
	table.insert(lines, "")
	local reply, first = summary(run)
	local reply_start = first and #lines + first
	vim.list_extend(lines, reply)
	local reply_end = #lines
	if #run.commands > 0 then
		vim.list_extend(lines, { "", "Commands" })
		vim.list_extend(lines, run.commands)
	end
	local title = ("Codex review · %d files"):format(files)
	if run.thread then
		title = title .. " · Chat " .. run.thread:sub(-6)
	end
	local buf, win = M.float(lines, { title = title, focus = true, height = 21, width = 100 })
	if reply_start and reply_start <= reply_end then
		M.markdown(buf, win, { { reply_start, reply_end } })
	end
	vim.bo[buf].modifiable = false
	local function close()
		vim.api.nvim_win_close(win, true)
	end
	local function map(key, callback)
		vim.keymap.set("n", key, callback, { buffer = buf, nowait = true })
	end
	map("q", close)
	map("<Esc>", close)
	map("r", function()
		local hunk = by_row[vim.api.nvim_win_get_cursor(win)[1]]
		close()
		follow_up(hunk)
	end)
	map("d", function()
		local hunk = by_row[vim.api.nvim_win_get_cursor(win)[1]]
		local diff = hunk and vim.list_extend({ hunk.path, hunk.header }, hunk.lines)
			or vim.split(run.diff, "\n", { plain = true })
		local diff_buf, diff_win = M.float(diff, { title = "Codex diff", focus = true, height = 23, width = 100 })
		vim.bo[diff_buf].filetype = "diff"
		vim.bo[diff_buf].modifiable = false
		vim.keymap.set("n", "q", function()
			vim.api.nvim_win_close(diff_win, true)
		end, { buffer = diff_buf, nowait = true })
	end)
	map("<CR>", function()
		local hunk = by_row[vim.api.nvim_win_get_cursor(win)[1]]
		if not hunk then
			return
		end
		local path = vim.fs.normalize(run.root .. "/" .. hunk.path)
		if hunk.deleted or not vim.startswith(path, run.root == "/" and "/" or run.root .. "/")
			or vim.fn.filereadable(path) == 0
		then
			vim.notify("This hunk is available in the diff (d).", vim.log.levels.INFO)
			return
		end
		close()
		vim.cmd.edit({ args = { path }, mods = { hide = true } })
		vim.api.nvim_win_set_cursor(0, { math.min(hunk.line, vim.api.nvim_buf_line_count(0)), 0 })
	end)
	if #hunks > 0 then
		vim.api.nvim_win_set_cursor(win, { 3, 0 })
	end
end

return M
