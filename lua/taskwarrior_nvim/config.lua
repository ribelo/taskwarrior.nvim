local M = {
	activity_events = {
		"BufWritePre",
		"InsertLeave",
	},
	filter = { "noice", "nofile" },
	task_file_name = ".taskwarrior.json",
	granulation = 60 * 1000 * 15,
	notify_start = true,
	notify_stop = true,
	notify_error = true,
	default_task_file = {
		description = {
			{ command = { "git", "remote", "get-url", "origin" }, regex = "https://github.com/([^/]+/[^/]+)%.git" },
			{ text = ":" },
			{ command = { "git", "rev-parse", "--abbrev-ref", "HEAD" } },
		},
	},
}

return M
