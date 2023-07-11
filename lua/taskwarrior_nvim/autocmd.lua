local config = require("taskwarrior_nvim.config")
local State = require("taskwarrior_nvim.state")
local taskwarrior = require("taskwarrior_nvim.taskwarrior")

---@type {[string]: string? }
local cmd_cache = {}
local M = {}
M.run_task_watcher = function()
	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		callback = function()
			local bufnr = vim.api.nvim_get_current_buf()
			local buf_filetype = vim.api.nvim_buf_get_option(0, "filetype")
			local buf_type = vim.api.nvim_buf_get_option(0, "buftype")
			if not vim.tbl_contains(config.filter, buf_filetype) and not vim.tbl_contains(config.filter, buf_type) then
				local cwd = vim.fn.getcwd()
				if cwd then
					local path = cmd_cache[cwd]
					---@type TaskConfig?
					local task_config
					if not path then
						path, task_config = taskwarrior.look_for_task_config(cwd)
					end
					if path and task_config then
						cmd_cache[cwd] = path
						local err, task = task_config:get_task()
						if err then
							vim.notify(err, vim.log.levels.ERROR)
						elseif not err and task then
							State:start_task(path, bufnr, task)
						end
					end
				end
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
		callback = function()
			State:stop_all()
		end,
	})
end

return M
