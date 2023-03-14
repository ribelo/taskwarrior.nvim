local M = {
	filter = { "noice", "nofile" },
	task_file_name = ".taskwarrior.json",
	granulation = 60 * 1000 * 10,
	notify_start = true,
	notify_stop = true,
	notify_error = true,
}

return M
