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
				if state.cwd == cwd then
					state:refresh()
				elseif cwd and state:cache_get(cwd) then
					state:set_cwd(cwd)
					state:set_task(state:cache_get(cwd))
				else
					taskwarrior.get_task_from_cwd(function(err, task)
						if err then
							vim.notify(err, vim.log.levels.ERROR)
						elseif task then
							if cwd then
								state:set_cwd(cwd)
								state:cache_set(cwd, task)
							end
							state:set_task(task)
						elseif not task then
							state:stop_task()
						end
					end)
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
		callback = function()
			vim.notify("Stopping task...", vim.log.levels.INFO, {})
			state:stop_task()
		end,
	})
end

return M
