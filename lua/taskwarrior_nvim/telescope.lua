local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")
local taskwarrior = require("taskwarrior_nvim.taskwarrior")

local M = {}

--[[
This function takes a Lua function `action` as a parameter and returns another
function. The returned function receives no parameters and runs the provided
`action` function with a `Task` object selected in the `actions_state` map.

#### Parameters:
- `action` (`function`): A Lua function that takes a `Task` object as a
  parameter and performs some action.

### Returns:
- `function`: A Lua function that takes no parameters and runs the provided
  `action` function with a selected `Task` object.

### Usage:
```lua
-- Define a function that logs the name of a given task
local function log_task_name(task)
  print(task.name)
end

-- Call make_action with a logging action
local selected_task_logger = make_action(log_task_name)

-- Call the returned function to perform the logging action on the selected
-- task in actions_state
selected_task_logger()
```
--]]
---@param action fun(task: Task)
local function make_action(action)
	---@type {value: Task}
	local entry = actions_state.get_selected_entry()
	local task = entry.value
	action(task)
end

M.browser = function(args)
	local displayer = entry_display.create({
		separator = "  ",
		items = {
			{ width = 3, right_justify = true },
			{ width = 3 },
			{ width = 12, right_justify = true },
			{ remaining = true },
		},
	})

	---@param task Task
	local make_display = function(task)
		---@type string?
		local elapsed_str
		if task.start_ then
			local elapsed = taskwarrior.time_elapsed(task.start_)
			if elapsed.days > 0 then
				elapsed_str = elapsed.days .. "d " .. elapsed.hours .. "h " .. elapsed.hours .. "m"
			elseif elapsed.hours > 0 then
				elapsed_str = elapsed.hours .. "h" .. elapsed.hours .. "m"
			elseif elapsed.minutes > 0 then
				elapsed_str = elapsed.minutes .. "m"
			elseif elapsed.seconds > 0 then
				elapsed_str = elapsed.seconds .. "s"
			elseif elapsed.seconds == 0 then
				elapsed_str = "now"
			end
		end
		return displayer({
			{ task.id, "TelescopeResultsNumber" },
			{ tostring(task.urgency):sub(0, 3) },
			{ elapsed_str or "" },
			{ task.description },
		})
	end

	local entry_maker = function(line)
		local err, task = taskwarrior.task_from_json(line)
		if not err and task then
			return {
				value = task,
				display = make_display(task),
				ordinal = task.description,
			}
		end
	end

	local create_finder = function()
		return finders.new_oneshot_job({
			"task",
			"export",
			"rc.json.array=0",
			"rc.confirmation=off",
			"rc.json.depends.array=on",
			unpack(args),
		}, { entry_maker = entry_maker })
	end

	local attach_mappings = function(prompt_bufnr, map)
		---@type Picker
		local current_picker = actions_state.get_current_picker(prompt_bufnr)

		-- map({ "i", "n" }, "<C-u>", actions.preview_scrolling_up(prompt_bufnr))
		-- map({ "i", "n" }, "<C-d>", actions.preview_scrolling_down(prompt_bufnr))

		map({ "i", "n" }, "<M-S-d>", function()
			make_action(function(task)
				task:delete(function(j, _code, _signal)
					vim.schedule(function()
						vim.notify(table.concat(j:result()), vim.log.levels.INFO, {})
					end)
					current_picker:refresh(create_finder(), {})
				end):start()
			end)
		end)

		map({ "i", "n" }, "<M-d>", function()
			make_action(function(task)
				task:done(function(j, _code, _signal)
					vim.schedule(function()
						vim.notify(table.concat(j:result()), vim.log.levels.INFO, {})
					end)
					current_picker:refresh(create_finder(), {})
				end):start()
			end)
		end)

		map({ "i", "n" }, "<M-s>", function()
			make_action(function(task)
				if task.start_ then
					task:stop(function(j, _code, _signal)
						vim.schedule(function()
							vim.notify(table.concat(j:result()), vim.log.levels.INFO, {})
						end)
						current_picker:refresh(create_finder(), {})
					end):start()
				else
					task:start(function(j, _code, _signal)
						vim.schedule(function()
							vim.notify(table.concat(j:result()), vim.log.levels.INFO, {})
						end)
						current_picker:refresh(create_finder(), {})
					end):start()
				end
			end)
		end)

		map({ "i", "n" }, "<M-y>", function()
			make_action(function(task)
				vim.schedule(function()
					vim.notify("yanked task uuid", vim.log.levels.INFO, {})
				end)
				vim.fn.setreg("+", task.uuid)
			end)
		end)

		map({ "i", "n" }, "<M-c>", function()
			make_action(function(_task)
				local cmd = vim.fn.input("Custom command: ")
				taskwarrior
					.cmd({ unpack(vim.split(cmd, " ")) }, {
						on_exit = function(j, _code, _singal)
							current_picker:refresh(create_finder(), {})
							vim.schedule(function()
								vim.notify(table.concat(j:result(), " "), vim.log.levels.INFO, {})
							end)
						end,
					})
					:start()
			end)
		end)

		map({ "i", "n" }, "<M-a>", function()
			make_action(function(_task)
				local cmd = vim.fn.input("Add: ")
				taskwarrior
					.cmd({ "add", unpack(vim.split(cmd, " ")) }, {
						on_exit = function(j, _code, _singal)
							current_picker:refresh(create_finder(), {})
							vim.schedule(function()
								vim.notify(table.concat(j:result(), " "), vim.log.levels.INFO, {})
							end)
						end,
					})
					:start()
			end)
		end)

		map({ "i", "n" }, "<M-p>", function()
			make_action(function(task)
				-- vim.api.nvim_feedkeys(":Taskwarrior " .. task.uuid, "n", false)
				local cmd = vim.fn.input("Enter command: ")
				task:cmd(vim.split(cmd, " "), function(j, _code, _signal)
					vim.schedule(function()
						vim.notify(table.concat(j:result(), " "), vim.log.levels.INFO, {})
					end)
					current_picker:refresh(create_finder(), {})
				end):start()
			end)
		end)
		return true
	end

	local previewer = previewers.new({
		---@param entry {value: Task}
		preview_fn = function(_, entry, status)
			local previewer_buffer = vim.api.nvim_win_get_buf(status.preview_win)
			entry.value
				:details(vim.schedule_wrap(function(err, lines)
					if not err then
						vim.api.nvim_buf_set_lines(previewer_buffer, 0, -1, false, lines)
					else
						vim.api.nvim_buf_set_lines(previewer_buffer, 0, -1, false, { err })
					end
				end))
				:start()
			-- entry.value:as_lines(vim.schedule_wrap(function(err, lines)
			-- 	if not err then
			-- 		vim.api.nvim_buf_set_lines(previewer_buffer, 0, -1, false, lines)
			-- 	else
			-- 		vim.api.nvim_buf_set_lines(previewer_buffer, 0, -1, false, { err })
			-- 	end
			-- end))
		end,
	})

	local opts = {
		finder = create_finder(),
		previewer = previewer,
		attach_mappings = attach_mappings,
	}

	pickers
		.new(opts, {
			prompt_title = "taskwarrior",
			---@diagnostic disable-next-line: no-unknown
			sorter = conf.generic_sorter(opts),
		})
		:find()
end

return M
