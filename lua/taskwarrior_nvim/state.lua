local Job = require("plenary.job")
local config = require("taskwarrior_nvim.config")

---@class State
---@field private cache? {[string]: {task: Task, idle_timer: uv_timer_t, activity_watchers: table<integer, integer>, is_running: boolean}}
local State = {
	cache = {},
}

---@param path string
---@return uv_timer_t?
function State:start_idle_timer(path)
	if not self.cache[path].idle_timer then
		local timer = vim.loop.new_timer()
		if timer then
			timer:start(config.granulation, 0, function()
				self:stop_task(path)
			end)
			self.cache[path].idle_timer = timer
			return timer
		end
	end
end

--- Stops an idle timer associated with given cwd
---@param path string - Current working directory
---@return boolean
function State:stop_idle_timer(path)
	-- Verify if the provided cwd exists in the cache
	if self.cache[path] then
		-- Stop the timer if found
		if self.cache[path].idle_timer then
			self.cache[path].idle_timer:stop()
		end
		return true
	end
end

--- Resets an idle timer associated with given cwd
---@param path string - Current working directory
---@return uv_timer_t?
function State:reset_idle_timer(path)
	local timer = self.cache[path].idle_timer
	if timer then
		timer:stop()
		self.cache[path].idle_timer = nil
	end
	return timer
end

---@param path string
---@return uv_timer_t?
function State:refresh_idle_timer(path)
	local timer = self.cache[path].idle_timer
	if timer then
		timer:stop()
		timer:start(config.granulation, 0, function()
			self:stop_task(path)
		end)
		return timer
	end
end

---@param path string
---@param bufnr integer
---@return integer?
function State:register_activity_watcher(path, bufnr)
	if not self.cache[path].activity_watchers then
		self.cache[path].activity_watchers = {}
	end
	if not self.cache[path].activity_watchers[bufnr] then
		local id = vim.api.nvim_create_autocmd(config.activity_events, {
			callback = function()
				self:refresh_task(path)
			end,
		})
		self.cache[path].activity_watchers[bufnr] = id
		return id
	end
end

---@param path string
---@param bufnr integer
---@return integer?
function State:unregister_activity_watcher(path, bufnr)
	local id = self.cache[path].activity_watchers[bufnr]
	if id then
		vim.api.nvim_del_autocmd(id)
		return id
	end
end

function State:stop_all()
	-- Stop all timers and remove them from the cache
	for path, data in pairs(self.cache) do
		for bufnr, _ in pairs(data.activity_watchers) do
			self:unregister_activity_watcher(path, bufnr)
		end
		self:stop_task(path)
		self:stop_idle_timer(path)
	end
end

function State:stop_task(path)
	if self.cache[path] and self.cache[path].task then
		vim.schedule(function()
			self.cache[path].task
				:stop(function(_j, _code, _signal)
					if config.notify_stop then
						vim.notify(
							"Task '" .. self.cache[path].task.description .. "' has stopped.",
							vim.log.levels.INFO,
							{}
						)
					end
					self.cache[path].is_running = false
					self:stop_idle_timer(path)
				end)
				:sync()
		end)
	end
end

---@param path string
---@param bufnr integer
---@param task Task
function State:start_task(path, bufnr, task)
	if self.cache[path] then
		if task.uuid == self.cache[path].task.uuid then
			if not self.cache[path].is_running then
				vim.schedule(function()
					task:start(function(_j, _code, _signal)
						if config.notify_start then
							vim.notify(
								"Task '" .. self.cache[path].task.description .. "' has started.",
								vim.log.levels.INFO,
								{}
							)
						end
						self.cache[path].is_running = true
					end):start()
				end)
				if not self:refresh_idle_timer(path) then
					vim.schedule(function()
						self:start_idle_timer(path)
					end)
				end
			else
				if not self:refresh_idle_timer(path) then
					vim.schedule(function()
						self:start_idle_timer(path)
					end)
				end
				self.cache[path].is_running = true
			end
		else
			self:stop_task(path)
			task:start(function(_j, _code, _signal)
				if config.notify_start then
					vim.notify("Task '" .. task.description .. "' has started.", vim.log.levels.INFO, {})
				end
				self.cache[path] = {
					task = task,
					is_running = true,
				}
				vim.schedule(function()
					self:start_idle_timer(path)
					self:register_activity_watcher(path, bufnr)
				end)
			end):sync()
		end
	else
		task:start(vim.schedule_wrap(function(_j, _code, _signal)
			if config.notify_start then
				vim.notify("Task '" .. task.description .. "' has started.", vim.log.levels.INFO, {})
			end
			self.cache[path] = {
				task = task,
				is_running = true,
			}
			vim.schedule(function()
				self:start_idle_timer(path)
				self:register_activity_watcher(path, bufnr)
			end)
		end)):sync()
	end
end

function State:refresh_task(path, bufnr)
	local task = self.cache[path].task
	if task then
		self:start_task(path, bufnr, task)
	end
end

return State
