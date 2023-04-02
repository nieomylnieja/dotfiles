-- Copied and slighlt modifed from: https://github.com/LunarVim/LunarVim/blob/rolling/lua/lvim/core/log.lua
local Log = {}
local home_path = os.getenv "HOME"

local notify_opts = {}

function Log:init()
  local status_ok, structlog = pcall(require, "structlog")
  if not status_ok then
    return nil
  end

  local log_level = Log.levels["INFO"]
  local log = {
    nieomylnieja = {
      pipelines = {
        -- TODO: Clean this up, If I prefer notifications go with them, oterwise remove notifications.
        -- I should only use one at the end of the day.
        -- structlog.sinks.Console(log_level, {
        --   async = true,
        --   processors = {
        --     structlog.processors.Namer(),
        --     structlog.processors.StackWriter({ "line", "file" }, { max_parents = 0, stack_level = 2 }),
        --     structlog.processors.Timestamper "%H:%M:%S",
        --   },
        --   formatter = structlog.formatters.FormatColorizer(
        --     "%s [%-5s] %s: %-30s",
        --     { "timestamp", "level", "logger_name", "msg" },
        --     { level = structlog.formatters.FormatColorizer.color_level() }
        --   ),
        -- }),
        level = log_level,
        processors = {
          structlog.processors.StackWriter({ "line", "file" }, { max_parents = 3, stack_level = 2 }),
          structlog.processors.Timestamper "%F %H:%M:%S",
        },
        structlog.sinks.File(log_level, self:get_path(), {
          processors = {
          },
          formatter = structlog.formatters.Format( --
            "%s [%-5s] %s: %-30s",
            { "timestamp", "level", "logger_name", "msg" }
          ),
        }),
      },
    },
  }

  structlog.configure(log)
  local logger = structlog.get_logger "nieomylnieja"

  vim.notify = function(msg, vim_log_level, opts)
    notify_opts = opts or {}

    -- vim_log_level can be omitted
    if vim_log_level == nil then
      vim_log_level = Log.levels["INFO"]
    elseif type(vim_log_level) == "string" then
      vim_log_level = Log.levels[(vim_log_level):upper()] or Log.levels["INFO"]
    else
      -- https://github.com/neovim/neovim/blob/685cf398130c61c158401b992a1893c2405cd7d2/runtime/lua/vim/lsp/log.lua#L5
      vim_log_level = vim_log_level + 1
    end

    logger:log(vim_log_level, msg)
  end

  return logger
end

--- Configure the sink in charge of logging notifications
---@param notify_handle table The implementation used by the sink for displaying the notifications
function Log:configure_notifications(notify_handle)
  local status_ok, structlog = pcall(require, "structlog")
  if not status_ok then
    return
  end

  local notify_opts_injecter = function(_, entry)
    for key, value in pairs(notify_opts) do
      entry[key] = value
    end
    notify_opts = {}
    return entry
  end

  local sink = structlog.sinks.NvimNotify(Log.levels.INFO, {
    processors = {
      notify_opts_injecter,
    },
    formatter = structlog.formatters.Format( --
      "%s",
      { "msg" },
      { blacklist_all = true }
    ),
    -- This should probably not be hard-coded
    params_map = {
      icon = "icon",
      keep = "keep",
      on_open = "on_open",
      on_close = "on_close",
      timeout = "timeout",
      title = "title",
    },
    impl = notify_handle,
  })

  local handle = self:get_logger()
  table.insert(handle.sinks, sink)
end

--- Adds a log entry using Plenary.log
---@param level integer [same as vim.log.levels]
---@param msg any
---@param event any
function Log:add_entry(level, msg, event)
  local logger = self:get_logger()
  if not logger then
    return
  end
  logger:log(level, vim.inspect(msg), event)
end

---Retrieves the handle of the logger object
---@return table|nil logger handle if found
function Log:get_logger()
  if self.__handle then
    return self.__handle
  end

  local logger = self:init()
  if not logger then
    return
  end

  self.__handle = logger
  return logger
end

---Retrieves the path of the logfile
---@return string path of the logfile
function Log:get_path()
  return string.format("%s/.local/share/nvim/%s.log", home_path, "nieomylnieja")
end

---Add a log entry at TRACE level
---@param msg any
---@param event any
function Log:trace(msg, event)
  self:add_entry(self.levels.TRACE, msg, event)
end

---Add a log entry at DEBUG level
---@param msg any
---@param event any
function Log:debug(msg, event)
  self:add_entry(self.levels.DEBUG, msg, event)
end

---Add a log entry at INFO level
---@param msg any
---@param event any
function Log:info(msg, event)
  self:add_entry(self.levels.INFO, msg, event)
end

---Add a log entry at WARN level
---@param msg any
---@param event any
function Log:warn(msg, event)
  self:add_entry(self.levels.WARN, msg, event)
end

---Add a log entry at ERROR level
---@param msg any
---@param event any
function Log:error(msg, event)
  self:add_entry(self.levels.ERROR, msg, event)
end

setmetatable({}, Log)

return Log
