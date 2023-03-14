local Job = require("plenary.job")
local config = require("taskwarrior_nvim.config")

---@class State
---@field current_task? Task
---@field timer? uv_timer_t
---@field cwd? string
---@field cache? {[string]: Task}
---@field private stop_timer fun(self)
local State = {
	current_task = nil,
	timer = nil,
	cwd = nil,
	cache = {},
}

function State:set_cwd(cwd)
	self.cwd = cwd
end

function State:reset()
	self.current_task = nil
	self.timer = nil
end

function State:stop_timer()
	if self.timer then
		self.timer:stop()
		self.timer = nil
	end
end

function State:stop_task()
	self:stop_timer()
	if self.current_task then
		local msg = "Task '" .. self.current_task.description .. "' has stopped."
		self.current_task
			:stop(function(_j, _code, _signal)
				vim.notify(msg, vim.log.levels.INFO, {})
				self.current_task = nil
			end)
			:start()
	end
end

---@param cwd string
---@param task Task
function State:cache_set(cwd, task)
	if not self.cache[cwd] then
		self.cache[cwd] = {}
	end
	self.cache[cwd] = task
end

---@param cwd string
function State:cache_get(cwd)
	if self.cache[cwd] then
		return self.cache[cwd]
	end
end

---@param task Task
function State:start_task(task)
	-- If the current task already exists and the uuids match, refresh the state and return.
	if self.current_task and self.current_task.uuid == task.uuid then
		self:refresh()
		return
	end
	-- If there is already an existing current task, stop it first before setting a new one.
	if self.current_task then
		self.current_task
			:stop(function(_j, _code, _signal)
				if config.notify_stop then
					vim.notify("Task '" .. self.current_task.description .. "' has stopped.", vim.log.levels.INFO, {})
				end
			end)
			:sync()
	end
	-- Start the new task start it.
	task:start(function(_j, _code, _signal)
		if config.notify_start then
			vim.notify("Task '" .. task.description .. "' has started.", vim.log.levels.INFO, {})
		end
	end):sync()
	-- Set the new task as the current task.
	self.current_task = task
	-- Create a timer that will call 'stop_timer' on this State object after 10 minutes.
	-- The 'vim.defer_fn' function returns a timer ID that can be used to stop the timer.
	-- The time is in milliseconds hence the need to multiply minutes by 60 and 1000 to convert.
	self.timer = vim.defer_fn(function()
		self:stop_task()
	end, config.granulation)
end

function State:refresh()
	if self.current_task then
		self:stop_timer()
		self.timer = vim.defer_fn(function()
			self:stop_task()
		end, config.granulation)
	end
end

function State:notify_start()
	vim.notify("Starting task " .. self.current_task.description, vim.log.levels.INFO, {})
end

function State:notify_stop()
	vim.notify("Stopping task " .. self.current_task.description, vim.log.levels.INFO, {})
end

return State
