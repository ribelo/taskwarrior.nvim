local autocmd = require("taskwarrior_nvim.autocmd")

local M = {}

---@param opts? table
M.setup = function(opts)
	autocmd.run_change_watcher()
	autocmd.run_task_watcher()
end

M.browser = require("taskwarrior_nvim.telescope").browser

return M
