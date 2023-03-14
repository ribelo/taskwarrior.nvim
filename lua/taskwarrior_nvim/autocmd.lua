local config = require("taskwarrior_nvim.config")
local state = require("taskwarrior_nvim.state")
local taskwarrior = require("taskwarrior_nvim.taskwarrior")

local M = {}

M.run_change_watcher = function()
	vim.api.nvim_create_autocmd({ "TextChanged" }, {
		callback = function()
			state:refresh()
		end,
	})
end

M.run_task_watcher = function()
	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		callback = function()
			local buf_filetype = vim.api.nvim_buf_get_option(0, "filetype")
			local buf_type = vim.api.nvim_buf_get_option(0, "buftype")
			if not vim.tbl_contains(config.filter, buf_filetype) and not vim.tbl_contains(config.filter, buf_type) then
				local cwd = vim.loop.cwd()
				---@diagnostic disable-next-line: param-type-mismatch
				if state.cwd == cwd then
					state:refresh()
				elseif cwd and state:cache_get(cwd) then
					state:set_cwd(cwd)
					state:start_task(state:cache_get(cwd))
				elseif cwd then
					local task_config = taskwarrior.look_for_task_config()
					if task_config then
						local err, task = task_config:get_task()
						if task then
							state:set_cwd(cwd)
							state:start_task(task)
							state:cache_set(cwd, task)
						elseif err then
							if config.notify_error then
								vim.notify(err, vim.log.levels.ERROR, {})
							end
						else
						end
					else
						state:set_cwd(cwd)
						state:stop_task()
					end
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
		callback = function()
			if config.notify_stop then
				vim.notify("Task '" .. state.current_task.description .. "' has stopped.", vim.log.levels.INFO, {})
			end
			state:stop_task()
		end,
	})
end

return M
