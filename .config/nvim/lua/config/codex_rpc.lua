local M = {}

function M.connect(on_event, on_close)
	local pending, waiting = {}, {}
	local next_id, partial = 0, ""
	local ready = false
	local job
	local client = {}

	local function send(message)
		return job and job > 0 and vim.fn.chansend(job, vim.json.encode(message) .. "\n") > 0
	end

	local function request(method, params, callback)
		next_id = next_id + 1
		if send({ id = next_id, method = method, params = params }) then
			pending[next_id] = callback
		else
			callback(nil, "Could not send " .. method .. " to Codex")
		end
	end

	function client.request(method, params, callback)
		if ready then
			request(method, params, callback)
		else
			table.insert(waiting, { method, params, callback })
		end
	end

	function client.reply(id, result, message)
		if message then
			send({ id = id, error = { code = -32601, message = message } })
		else
			send({ id = id, result = result })
		end
	end

	local function receive(line)
		local ok, message = pcall(vim.json.decode, line)
		if not ok or type(message) ~= "table" then
			return
		end
		if message.method then
			on_event(client, message)
		elseif message.id and pending[message.id] then
			local callback = pending[message.id]
			pending[message.id] = nil
			callback(message.result, message.error and message.error.message)
		end
	end

	local stderr = ""
	local function close(message)
		local requests = pending
		local queued = waiting
		pending, waiting = {}, {}
		on_close(message)
		for _, callback in pairs(requests) do
			callback(nil, message)
		end
		for _, call in ipairs(queued) do
			call[3](nil, message)
		end
	end

	local executable = vim.fn.exepath("codex")
	if executable == "" then
		return nil, "Codex is unavailable on Neovim's PATH"
	end
	job = vim.fn.jobstart({ executable, "app-server", "--listen", "stdio://" }, {
		on_stdout = function(_, lines)
			lines[1] = partial .. lines[1]
			partial = table.remove(lines)
			for _, line in ipairs(lines) do
				receive(line)
			end
		end,
		on_stderr = function(_, lines)
			stderr = (stderr .. table.concat(lines, "\n")):sub(-1500)
		end,
		on_exit = function(_, code)
			local detail = vim.trim(stderr)
			close("Codex server exited (" .. code .. ")" .. (detail ~= "" and "\n" .. detail or ""))
		end,
	})
	if job <= 0 then
		return nil, "Could not launch the Codex app server"
	end
	request("initialize", { clientInfo = { name = "neovim", title = "Neovim", version = "0.1.0" } }, function(_, err)
		if err then
			if #waiting > 0 then
				local queued = waiting
				waiting = {}
				for _, call in ipairs(queued) do
					call[3](nil, err)
				end
			end
			vim.fn.jobstop(job)
			return
		end
		send({ method = "initialized" })
		ready = true
		local queued = waiting
		waiting = {}
		for _, call in ipairs(queued) do
			request(call[1], call[2], call[3])
		end
	end)
	return client
end

return M
