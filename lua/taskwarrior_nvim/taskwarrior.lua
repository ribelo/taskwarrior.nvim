local Job = require("plenary.job")
local config = require("taskwarrior_nvim.config")
local notify = require("taskwarrior_nvim.notify")

local M = {}

M.keys_to_show = {
  "id",
  "description",
  "annotations",
  "status",
  "project",
  "start",
  "entry",
  "modified",
  "end",
  "tags",
  "virtualtags",
  "urgency",
  "uuid",
}

--[[
## `M.time_elapsed`

Takes in a `date` string in the format `YYYY-MM-DD HH:MM:SS` and calculates the time elapsed since the date in terms of "days", "hours", "minutes", and "seconds".

### Parameters:
- `date` (`string`): The date in the format `YYYY-MM-DD HH:MM:SS`.

### Returns:
- `{days: number, hours: number, minutes: number, seconds: number}`: A table containing the breakdown of elapsed time in "days", "hours", "minutes", and "seconds".

### Usage:
```lua
local elapsed = M.time_elapsed("2022-01-25 13:30:00")
print("Days elapsed:", elapsed.days)
print("Hours elapsed:", elapsed.hours)
print("Minutes elapsed:", elapsed.minutes)
print("Seconds elapsed:", elapsed.seconds)
```
--]]
---@param date string
---@return {days: number, hours: number, minutes: number, seconds: number}
M.time_elapsed = function(date)
  -- Convert the date string to a table of year, month, day, hour, minute,
  -- second and get the time in seconds since epoch
  local time = os.time({
    year = tonumber(date:sub(1, 4)) or 0, -- parse the year from the string
    month = tonumber(date:sub(6, 7)) or 0, -- parse the month from the string
    day = tonumber(date:sub(9, 10)) or 0, -- parse the day from the string
    hour = tonumber(date:sub(12, 13)) or 0, -- parse the hour from the string
    min = tonumber(date:sub(15, 16)) or 0, -- parse the minute from the string
    sec = tonumber(date:sub(18, 19)) or 0, -- parse the second from the string
  })

  -- Get the current time in seconds since epoch in UTC
  ---@diagnostic disable-next-line: param-type-mismatch
  local now = os.time(os.date("!*t"))

  -- Calculate the difference between the given date and the current date and time
  local diff = now - time

  -- Calculate the number of elapsed days since given date
  local days = math.floor(diff / (24 * 60 * 60))
  -- Calculate the number of elapsed hours since given date
  local hours = math.floor((diff - days * 24 * 60 * 60) / (60 * 60))
  -- Calculate the number of elapsed minutes since given date
  local minutes =
    math.floor((diff - days * 24 * 60 * 60 - hours * 60 * 60) / 60)
  -- Calculate the number of elapsed seconds since given date
  local seconds =
    math.floor(diff - days * 24 * 60 * 60 - hours * 60 * 60 - minutes * 60)

  -- Return a table of elapsed time breakdown
  return { days = days, hours = hours, minutes = minutes, seconds = seconds }
end

--[[
This function takes a `date_string` parameter of type `string` as input and
returns a formatted string.

#### Input
- `date_string` (`string`): A date string in the format 'YYYYMMDD HHmmss'.

#### Returns
- `string`: A formatted string in the form 'YYYY-MM-DD HH:mm:ss'.

### Usage:
```lua
local date_string = '20220101 154500'
local formatted_date = parse_date(date_string)

-- formatted_date: "2022-01-01 15:45:00"
```
--]]
---@param date_string string
---@return string
local function parse_date(date_string)
  -- Split the input date string into separate date and time parts
  local date_part = string.sub(date_string, 1, 8)
  local time_part = string.sub(date_string, 10, 15)

  -- Format the date and time parts to include dashes and colons respectively
  local formatted_date = string.format(
    "%s-%s-%s",
    string.sub(date_part, 1, 4),
    string.sub(date_part, 5, 6),
    string.sub(date_part, 7, 8)
  )
  local formatted_time = string.format(
    "%s:%s:%s",
    string.sub(time_part, 1, 2),
    string.sub(time_part, 3, 4),
    string.sub(time_part, 5, 6)
  )

  -- Return the formatted date and time parts as a single string
  return string.format("%s %s", formatted_date, formatted_time)
end

--[[
### Purpose:

The function `notify` sends appropriate messages to the user interface using the `vim.notify` function, based on the status code provided.

### Input Parameters:

- `j` (`Job`): an instance of the `Job` class that contains the result of a previously executed job.
- `code` (`number`): the status code returned by the job execution. A value of 1 indicates that the job execution was successful, and a value of 0 indicates failure.
- `_` (`nil`): an optional parameter that is not used.

### Returns:

This function does not have a return statement.

### Usage:

```lua
local j = Job:new({
	command = "echo 'Hello, world!'", -- the command to execute
	on_exit = function(j)
		if j.code == 0 then
			notify(j, 0, nil) -- show error message
		else
			notify(j, 1, nil) -- show success message
		end
	end,
})
j:start()
```
--]]
---@param j Job
---@param code number
M.notify = function(j, code, _)
  local msg = table.concat(j:result(), "")
  vim.schedule(function()
    if code == 1 then
      notify(msg, vim.log.levels.INFO, {})
    else
      notify(msg, vim.log.levels.ERROR, {})
    end
  end)
end


---@alias on_exit fun(j: Job, code?: number, signal?: number)
---@alias on_stdout fun(err: string, data: string, j?: Job)
---@alias on_stderr fun(err: string, data: string, j?: Job)

--[[
### Function Description:
The function `make_takswarrior_job()` creates and returns a new `Job` object that runs a specified command with the given arguments.

### Input:
- `args` (`string[]`): an array that contains the arguments to be passed to the command.
- `opts` (`map`, optional): an optional map with the following properties:
	- `on_exit` (`function`, optional): an optional function that is called when the job exits. This function takes three optional arguments: `job` (Job object instance), `code` (number), and `signal` (number).
	- `on_stdout` (`function`, optional): an optional function that is called when there is output on stdout. This function takes three arguments: `err` (string), `data` (string), and `job` (Job object instance).
	- `on_stderr` (`function`, optional): an optional function that is called when there is output on stderr. This function takes three arguments: `err` (string), `data` (string), and `job` (Job object instance).

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
e``lua
-- Define a function to print output to the status line (requires a plugin like vim-airline)
function print_status_line(err, data, j)
	vim.api.nvim_command("let g:airline#parts#takswarrior = {}")
	vim.api.nvim_command("let g:airline#parts#takswarrior.text = 'Task Warrior: " .. data .. "'")
	vim.api.nvim_command("let g:airline#parts#takswarrior.color = 'black'")
end

-- Create a new job object to run a Task Warrior command with arguments 
local job = make_takswarrior_job({"stats"}, {
	on_stdout = print_status_line
})

-- Start the job object
job:start()
```
--]]
---@param args string[]
---@param opts? {on_exit?: on_exit, on_stdout?: on_stdout, on_stderr?: on_stderr}
---@return Job
local function make_task_job(args, opts)
  -- Define a default options table that specifies the command and args to be
  -- passed to the job object
  local default = {
    command = "task",
    args = args,
  }
  if opts then
    -- If an options table was passed to this function, use vim.tbl_extend to
    -- merge the passed options with the default options
    opts = vim.tbl_extend("force", default, opts)
  else
    -- If no options table was passed, use the default options
    opts = default
  end
  -- Create and return a new Job object with the options passed in
  local j = Job:new(opts)
  return j
end

--[[
This function creates a new instance of a Job, accepting an array of strings as
input parameters, and an optional table of options.

### Parameters:

- `args` (`string[]`): Array of strings representing arguments passed to the `task`.
- `opts` (`table`, optional): A table of options used to customize the execution of the Job.
	- `on_exit` (`function`): Callback function invoked on Job's termination
	- `on_stdout` (`function`): Callback function invoked on Job's standard output
	- `on_stderr` (`function`): Callback function invoked on Job's standard error

### Returns:

- `Job`: A new instance of a Job representing a running process.

### Usage:

```lua
local args = {"add", "foo"}
local opts = {on_exit = function(j, _, _) vim.notify(j:result(), ...) end}
local job = M.cmd(args, opts):start()
```
--]]
---@param args string[]
---@param opts? {on_exit?: on_exit, on_stdout: on_stdout, on_stderr: on_stderr}
---@return Job
M.cmd = function(args, opts)
  return make_task_job({ "rc.confirmation=0", unpack(args) }, opts)
end

---@return number
M.add_task = function(args)
  ---@type string
  local id
  M.cmd({ "add", unpack(args) }, {
    on_exit = function(j, _code, _signal)
      id = string.match(j:result()[1], "%d+")
    end,
  }):sync()
  ---@diagnostic disable-next-line: return-type-mismatch
  return tonumber(id)
end

---@return string?, Task?
M.get_task_by_key = function(k, v)
  local err, tasks = M.get_tasks()
  if err then
    return err, nil
  elseif tasks then
    for _, task in ipairs(tasks) do
      if task[k] == v then
        return nil, task
      end
    end
  else
    return "No tasks found", nil
  end
end

--[[ 
The function `as_json()` creates and returns a new `Job` object that runs the
`task export` command with the given arguments.

### Input:
- `args` (`string[]`): an array that contains the arguments to be passed to the
`task export` command.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local args = {"foo"}
local opts = {on_exit = function(j, _, _) vim.notify(j:result(), ...) end}
local job = M.as_json(args, opts):start()
```
--
--]]
---@param args string[]
---@param opts {on_exit: on_exit, on_stdout: on_stdout, on_stderr: on_stderr}
---@return Job
local function as_json(args, opts)
  return make_task_job({ "export", unpack(args) }, opts)
end

---@class Task
---@field id number
---@field uuid string
---@field description string
---@field start_ string?
---@field end_ string
---@field entry string
---@field modified string
---@field status "pending"|"deleted"|"completed"|"recurring"
---@field urgency number
---
local Task = {}
Task.__index = Task
M.Task = Task

---@param o table
---@return Task
function Task:new(o)
  return setmetatable(o, self)
end

---@class TaskConfigCommand
---@field text? string
---@field command? string[]
---@field regex? string

---@class TaskConfig
---@field id? string
---@field description? TaskConfigCommand[]
---@field project? TaskConfigCommand[]
---@field tags? TaskConfigCommand[]
---
local TaskConfig = {}
TaskConfig.__index = TaskConfig
M.TaskConfig = TaskConfig

---@param o? table
function TaskConfig:new(o)
  return setmetatable(o or {}, TaskConfig)
end

function TaskConfig:validate()
  if not self.id and not self.description then
    return "Missing required field `id` or `description`"
  end
  if not self.id and type(self.description) == "table" then
    return "If there is no field `id`, `description` must be an array of commands."
  end
end

--[[
### Description:
This function recursively searches for a `.taskwarrior.json` configuration file
starting from a given path and moving up the directory tree until found or the
root directory is reached.

### Parameters:
- `path` (`string`): The directory path to start the search from.

### Returns:
- `string`: The full path to the found `.taskwarrior.json` configuration file if found.
- `number`: The file descriptor of the found `.taskwarrior.json` configuration file if found.
- `nil, nil`: If no configuration file is found after searching the entire directory tree up to the root.

### Usage:
Suppose we have a directory tree structure like:
```
├── project
│   ├── .taskwarrior.json
│   ├── subdir1
│   ├── subdir2
│   │   ├── userdata
│   │   ├── logs
```

1. Start searching from 'subdir1'.
```lua
local config_path, file_descriptor = find_task_config_recursive("path/to/project/subdir1")
print(config_path)  -- Output: path/to/project/.taskwarrior.json
```
2. Start searching from 'logs' directory.
```lua
local config_path, file_descriptor = find_task_config_recursive("path/to/project/subdir2/logs")
print(config_path)  -- Output: path/to/project/.taskwarrior.json
```
3. If the configuration file does not exist in the directory tree, both returned values will be `nil`.
```lua
local config_path, file_descriptor = find_task_config_recursive("path/to/another_project")
print(config_path)  -- Output: nil
print(file_descriptor)  -- Output: nil
```
--]]
---@return string?, integer?
local function find_task_config_recursive(path)
  local file = (path or "") .. "/.taskwarrior.json"
  local fd = vim.uv.fs_open(file, "r", 438)

  if fd then
    return file, fd
  end

  local parent_path = vim.fn.fnamemodify(path, ":h")
  if parent_path == path then
    return nil, nil
  end

  return find_task_config_recursive(parent_path)
end

local function readFileSync(fd)
  local stat = assert(vim.uv.fs_fstat(fd))
  local data = assert(vim.uv.fs_read(fd, stat.size, 0))
  assert(vim.uv.fs_close(fd))
  return data
end

--[[
This function is responsible for searching for a task file named
`.taskwarrior.json` in the current working directory and its parent
directories. If found, the function reads the file and returns the path
and the parsed TaskConfig.

### Args:

None

### Returns:

- `path` (string|nil): The path to the found task file, or nil if not found.
- `task_config` (TaskConfig|nil): The parsed TaskConfig object, or nil if not found or parsing failed.

### Usage:

```lua
-- Example usage of look_for_task_config()
local path, task_config = M.look_for_task_config()
if path ~= nil and task_config ~= nil then
    print("Found task at path:", path)
    print("Task config:", task_config)
else
    print("Task not found or failed to parse.")
end

--]]
---@return string?, TaskConfig?
M.look_for_task_config = function(root)
  if not root then
    root = vim.uv.cwd()
  end
  local path, fd = find_task_config_recursive(root)

  if not fd then
    return nil, nil
  end

  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.api.nvim_err_writeln("Can't read file stat.")
    vim.uv.fs_close(fd)
    return nil, nil
  end

  local data = vim.uv.fs_read(fd, stat.size, 0)
  vim.print(vim.inspect(data))
  vim.print("4")
  vim.loop.fs_close(fd)

  if not data or data == "" then
    return nil, nil
  end

  local success, decoded_data = pcall(vim.json.decode, data)
  if not success then
    vim.api.nvim_err_writeln("Failed to parse JSON data.")
    return nil, nil
  end

  vim.print("5")
  return path, TaskConfig:new(decoded_data)
end

---@return string?, Task?
function TaskConfig:get_task()
  ---@type {err?: string, task?: Task}
  local r = {}
  if self.id and type(self.id) == "string" then
    M.cmd({ self.id, "export", "rc.json.array=0" }, {
      on_exit = function(j, _code, _signal)
        local data = j:result()
        if data then
          local err, task = M.task_from_json(data[1])
          r.err = err
          r.task = task
        else
          r.err = "Can't find task: " .. self.id
        end
      end,
    }):sync()
    return r.err, r.task
  elseif not self.id and self.description then
    ---@type table
    local description = {}
    local project = {}
    local tags = {}
    for i, v in ipairs(self.description) do
      if v.text then
        table.insert(description, v.text)
      elseif v.command then
        Job
          :new({
            command = v.command[1],
            args = vim.list_slice(v.command, 2),
            on_exit = function(j, _code, _signal)
              local data = table.concat(j:result())
              if not data or data == "" then
                r.err = "The configuration command ["
                  .. i
                  .. "] for descroption returns an empty string."
                return r.err, r.task
              elseif data and v.regex then
                table.insert(description, string.match(data, v.regex))
              elseif data and not v.regex then
                table.insert(description, data)
              end
            end,
          })
          :sync()
      end
    end
    for i, v in ipairs(self.project or {}) do
      if v.text then
        table.insert(project, v.text)
      elseif v.command then
        Job
          :new({
            command = v.command[1],
            args = vim.list_slice(v.command, 2),
            on_exit = function(j, _code, _signal)
              local data = table.concat(j:result())
              if not data or data == "" then
                r.err = "The configuration command ["
                  .. i
                  .. "] for project returns an empty string."
                return r.err, r.task
              elseif data and v.regex then
                table.insert(project, string.match(data, v.regex))
              elseif data and not v.regex then
                table.insert(project, data)
              end
            end,
          })
          :sync()
      end
    end
    for i, v in ipairs(self.tags or {}) do
      if v.text then
        table.insert(tags, v.text)
      elseif v.command then
        Job
          :new({
            command = v.command[1],
            args = vim.list_slice(v.command, 2),
            on_exit = function(j, _code, _signal)
              local data = table.concat(j:result())
              if not data then
                r.err = "The configuration command ["
                  .. i
                  .. "] for tags returns an empty string."
                return r.err, r.task
              elseif data and v.regex then
                table.insert(tags, string.match(data, v.regex))
              elseif data and not v.regex then
                table.insert(tags, data)
              end
            end,
          })
          :sync()
      end
    end
    r.err, r.task = M.get_task_by_key("description", table.concat(description))
    if r.task then
      return r.err, r.task
    else
      local args = {}
      table.insert(args, table.concat(description))
      if #project > 0 then
        table.insert(args, "project:" .. table.concat(project))
      end
      if #tags > 0 then
        table.insert(args, "tag:" .. table.concat(tags, ","))
      end
      local id = M.add_task(args)
      if id then
        r.err, r.task = M.get_task_by_key("id", tonumber(id))
        return r.err, r.task
      else
        r.err = "Can't find task: " .. table.concat(description)
        return r.err, r.task
      end
    end
  else
    r.err = "The field id or description is absent"
    return r.err, r.task
  end
end

-- vim.pretty_print(task)

--[[ 
The function `Task:new()` creates a new instance of a Task object.

### Input:
- `o` (`table`): a table that contains the data to be used to create the new
Task object.

### Returns:
- `Task`: a new instance of a Task object.

### Usage:
```lua
local t = Task:new({
	id = 1,
	description = "foo",
	start_ = nil,
	end_ = "2021-01-01",
	entry = "2021-01-01",
	modified = "2021-01-01",
	status = "pending",
	uuid = "1",
	urgency = 0.5,
})
```
--]]

--[[ 
The function `Task:cmd()` creates and returns a new `Job` object that runs the
`task` command on the given `task` with the given arguments.

### Input:
- `args` (`string[]`): an array that contains the arguments to be passed to the
`task` command.
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local args = {"delete"}
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
taks:cmd(args, on_exit):start()
```
--]]
---@param args string[]
---@param on_exit on_exit
---@return Job
function Task:cmd(args, on_exit)
  return M.cmd({ self.uuid, unpack(args) }, { on_exit = on_exit })
end

--[[
The function `Task:annotate()` creates and returns a new `Job` object that runs the
`task annotate` command on the given `task` with the given arguments.

### Input:
- annotation (`string`): the annotation to be added to the task.
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:annotate("foo", on_exit):start()
```
--]]
---@param annotation string
---@param on_exit? on_exit
---@return Job
function Task:annotate(annotation, on_exit)
  return M.cmd(
    { "annotate", tostring(self.uuid), annotation },
    { on_exit = on_exit }
  )
end

--[[
The function `Task:append()` creates and returns a new `Job` object that runs the
`task append` command on the given `task` with the given arguments.

### Input:
- text (`string`): the text to append to the task.
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:append("foo", on_exit):start()
```
--]]
---@param text string
---@param on_exit? on_exit
---@return Job
function Task:append(text, on_exit)
  return M.cmd({ "append", tostring(self.uuid), text }, { on_exit = on_exit })
end

--[[
The function `Task:prepend()` creates and returns a new `Job` object that runs the
`task prepend` command on the given `task` with the given arguments.

### Input:
- text (`string`): the text to be prepended to the task.
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:prepend("foo", on_exit):start()
```
--]]
---@param text string
---@param on_exit? on_exit
---@return Job
function Task:prepend(text, on_exit)
  return M.cmd({ "prepend", tostring(self.uuid), text }, { on_exit = on_exit })
end

--[[
The function `Task:delete()` creates and returns a new `Job` object that runs the
`task delete` command on the given `task` with the given arguments.

### Input:
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:delete(on_exit):start()
```
--]]
---@param on_exit? on_exit
---@return Job
function Task:delete(on_exit)
  return M.cmd({ "delete", tostring(self.uuid) }, { on_exit = on_exit })
end

--[[
The function `Task:purge()` creates and returns a new `Job` object that runs the
`task purge` command on the given `task` with the given arguments.

### Input:
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:purge(on_exit):start()
```
--]]
---@param on_exit? on_exit
---@return Job
function Task:purge(on_exit)
  return M.cmd({ "purge", tostring(self.uuid) }, { on_exit = on_exit })
end

--[[
The function `Task:denotate()` creates and returns a new `Job` object that runs the
`task denotate` command on the given `task` with the given arguments.

### Input:
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:denotate("foo", on_exit):start()
```
--]]
---@param on_exit? on_exit
---@return Job
function Task:denotate(on_exit)
  return M.cmd({ "denotate", tostring(self.uuid) }, { on_exit = on_exit })
end

--[[
The function `Task:done()` creates and returns a new `Job` object that runs the
`task done` command on the given `task` with the given arguments.

### Input:
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:done(on_exit):start()
```
--]]
---@param on_exit? on_exit
---@return Job
function Task:done(on_exit)
  return M.cmd({ "done", tostring(self.uuid) }, { on_exit = on_exit })
end

--[[
The function `Task:duplicate()` creates and returns a new `Job` object that runs the
`task duplicate` command on the given `task` with the given arguments.

### Input:
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:duplicate(on_exit):start()
```
--]]
---@param on_exit? on_exit
---@return Job
function Task:duplicate(on_exit)
  return M.cmd({ "duplicate", tostring(self.uuid) }, { on_exit = on_exit })
end

--[[
The function `Task:edit()` creates and returns a new `Job` object that runs the
`task edit` command on the given `task` with the given arguments.

### Input:
- nothing

### Returns:
- `Job`: a new Job object with the options passed in.

--[[
The function `Task:start()` creates and returns a new `Job` object that runs the
`task start` command on the given `task` with the given arguments.

### Input:
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:start(on_exit):start()
```
--]]
---@param on_exit? on_exit
---@return Job
function Task:start(on_exit)
  return M.cmd({ "start", tostring(self.uuid) }, { on_exit = on_exit })
end

--[[
The function `Task:denotate()` creates and returns a new `Job` object that runs the
`task denotate` command on the given `task` with the given arguments.

### Input:
- on_exit (`function`, optional): a callback function that will be invoked when
	the job terminates.

### Returns:
- `Job`: a new Job object with the options passed in.

### Usage:
```lua
local on_exit = function(j, _, _) vim.notify(j:result(), ...) end
task:denotate("foo", on_exit):start()
```
--]]
---@param on_exit? on_exit
---@return Job
function Task:stop(on_exit)
  return M.cmd({ "stop", tostring(self.uuid) }, {
    on_exit = on_exit,
  })
end

--[[
This function is a method of the `Task` class, and it converts a task to a JSON
string and then returns a `Job` object.

### Input:

- `on_result` (`function(err?: string, o?: table)`): a callback function that
	is called when the task is completed. This function takes two optional
	parameters: `err` of type `string` (in case an error occurs) and `o` of type
	`table` (this will contain the result of the operation).

#### Returns

`Job`: A `Job` object representing the asynchronous task to be executed.

#### Usage

```lua
local task = Task:new()
-- set task properties
-- ...

local on_result = function(err, result)
	if err then
		-- handle error case
	else
		-- handle success case
	end
end

local job = task:as_json(on_result)
job:start()
```
--]]
---@param on_result fun(err?: string, o?: table)
---@return Job
function Task:as_json(on_result)
  ---@type on_exit
  local on_exit = function(j, code, _)
    local text = table.concat(j:result())
    if code == 0 then
      local json = vim.json.decode(text)
      if json and json.error then
        on_result(json.error.message, nil)
      elseif json and not json.error then
        on_result(nil, json[1])
      end
    else
      on_result(text, nil)
    end
  end
  return as_json({ tostring(self.uuid) }, { on_exit = on_exit })
end

---@param on_result fun(err?: string, lines?: string[])
function Task:details(on_result)
  ---@type on_exit
  local on_exit = function(j, code, _signal)
    if code == 0 then
      on_result(nil, j:result())
    else
      on_result(table.concat(j:result()), nil)
    end
  end
  return make_task_job({ self.uuid }, { on_exit = on_exit })
end

--[[
This function generates and formats a task object as an array of strings before
passing the result to the callback function `on_result`.

#### Input Parameters
- `on_result` (`function`): A function to which the function passes the
	generated array of strings. It is called with two arguments; `err` and `lines`.
	If an error occurs during execution, `err` contains an error message string
	while `lines` is nil. If the execution runs successfully, `err` is nil while
	`lines` contains a table of strings (formatted with the respective task
	objects).

#### Returns
	- `nil`: The function does not return anything. It simply calls the `on_result`
	callback function with the resultant array of strings.

#### Usage
```lua
local task = Task:new{description = "Create comprehensive docstrings", status = "Open", tags= {"documentation", "Lua programming"}}
task:as_lines(function(err, lines)
    if err then
        print("Error: ", err)
    else
        for _, line in ipairs(lines) do
            print(line)
        end
    end
end)
```
--]]
---@param on_result fun(err?: string, lines?: string[])
function Task:as_lines(on_result)
  ---@type string?
  local longest_key = nil
  ---@type string?
  local longest_value = nil
  for _, k in ipairs(M.keys_to_show) do
    local v = tostring(self[k]) or ""
    v = tostring(v)
    if not longest_key or #k > #longest_key then
      longest_key = k
    end
    if not longest_value or #v > #longest_value then
      longest_value = v
    end
  end
  longest_key = longest_key .. "   "
  local bottom_line = "─"
  local arr = {
    string.format("%-" .. #longest_key .. "s", "Name")
      .. string.format("%-" .. #longest_value .. "s", "Value"),
  }
  table.insert(
    arr,
    string.rep(bottom_line, #longest_key)
      .. string.rep(bottom_line, #longest_value)
  )
  for _, k in ipairs(M.keys_to_show) do
    ---@type table
    local v
    if k == "end" then
      v = self.end_
    else
      v = self[k]
    end
    if not v then
      v = ""
    elseif k == "tags" then
      v = table.concat(v, " ")
    elseif k == "annotations" then
      local a = ""
      for _, m in ipairs(v) do
        a = a .. " " .. m.description
      end
      v = a
    else
      v = tostring(v)
    end
    local line = string.format("%-" .. #longest_key .. "s", k)
      .. string.format("%-" .. #longest_value .. "s", v)
    table.insert(arr, line)
  end
  on_result(nil, arr)
end

--[[
### `task_from_json` function

This function converts a JSON string into a `Task` object, parsing dates and cleaning up the `end`, `start`, `entry` and `modified` fields.

#### Input
- `s` (`string`): The JSON string representing a Task object.

#### Returns
- `string?`: An error message if the JSON string contains an error. `nil` if there is no error.
- `Task?`: A `Task` object constructed from the parsed JSON.

#### Usage
```lua
local my_task = M.task_from_json('{"id":1,"description":"My task","start":"2022-01-01T00:00:00Z","end":"2022-01-02T00:00:00Z","entry":"2022-01-01T00:00:00Z","modified":"2022-01-02T00:00:00Z"}')
if my_task then
	print(my_task.id) --> 1
end
```
--]]
---@param s string
---@return string?, Task?
M.task_from_json = function(s)
  if not s or s == "" then
    return "Unable to extract tasks from JSON: empty string.", nil
  end
  local json = vim.json.decode(s)
  if json and json.error then
    return json.error.message, nil
  elseif json and not json.error then
    ---@param k string
    ---@param v any
    for k, v in pairs(json) do
      if k == "end" then
        ---@diagnostic disable-next-line: no-unknown
        json[k] = nil
        json.end_ = parse_date(v)
      elseif k == "start" then
        ---@diagnostic disable-next-line: no-unknown
        json[k] = nil
        json.start_ = parse_date(v)
      elseif k == "entry" then
        json.entry = parse_date(v)
      elseif k == "modified" then
        json.modified = parse_date(v)
      end
    end
    return nil, Task:new(json)
  else
    return
  end
end

--[[
Generates a new Job that retrieves all tasks.

- `on_exit` (`function`): Callback function that gets triggered when the Job
  completes execution. It accepts two parameters: 
	- `err` (`string`): An error message if the Job execution fails.
	- `tasks` (`Task[]`, optional): An array of Task objects if the Job executes
	  successfully.

### Returns:
- `Job`: A new instance of the Job class that contains details of the `task`
  command to be executed.

### Usage:
```lua
M.get_tasks(function(err, tasks)
  if err then
    print("Error: " .. err)
  else
    for _, task in ipairs(tasks) do
      print(task.description)
    end
  end
end)
``` 
--]]
---@return string?, Task[]?
M.get_tasks = function()
  local r = { err = nil, result = nil }
  Job:new({
    command = "task",
    args = { "export", "ready", "rc.verbose=nothing", "rc.json.array=0" },
    ---@param j Job
    on_exit = function(j, code, _signal)
      if code == 0 then
        ---@type Task[]
        local tasks = {}
        ---@type string[]
        local lines = j:result()
        for _, line in ipairs(lines) do
          local err, task = M.task_from_json(line)
          if err then
            r.err = err
            return
          else
            table.insert(tasks, task)
          end
        end
        r.result = tasks
        return
      else
        r.err = "Unable to retrieve tasks."
        return
      end
    end,
  }):sync()
  return r.err, r.result
end

-- The `create_config_file` function creates a new file if it doesn't exist.
---@param path string? -- File path, uses a default path if not provided.
M.go_to_config_file = function(path, b)
  local data = vim.json.encode(config.default_task_file)
  if not data then
    return
  end
  -- Use default file path if not provided.
  if not path then
    path = vim.uv.cwd() or "."
  end
  local file = path .. "/" .. config.task_file_name
  local fd, _, _ = vim.uv.fs_open(file, "wx", 438)
  if fd then
    vim.uv.fs_write(fd, data, 0)
  end
  vim.cmd("e " .. file)
end

return M
