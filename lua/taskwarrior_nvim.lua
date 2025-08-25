local taskwarrior = require("taskwarrior_nvim.taskwarrior")
local autocmd = require("taskwarrior_nvim.autocmd")
local notify = require("taskwarrior_nvim.notify")

local M = {}

---@param opts? table
M.setup = function(opts)
	autocmd.run_task_watcher()

	---@param args {fargs: string[]}
	vim.api.nvim_create_user_command("Task", function(args)
		taskwarrior
			.cmd(args.fargs, {
				on_exit = function(j, _code, _signal)
					notify(table.concat(j:result()))
				end,
			})
			:start()
	end, {
		range = true,
		nargs = "*",
	})
end

M.browser = require("taskwarrior_nvim.telescope").browser
M.go_to_config_file = require("taskwarrior_nvim.taskwarrior").go_to_config_file

return M
