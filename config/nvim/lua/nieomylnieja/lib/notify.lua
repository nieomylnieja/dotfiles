local M = {}

local Log = require "nieomylnieja.lib.log"

local options = {
  active = true,
  on_config_done = nil,
  opts = {
    ---@usage Animation style one of { "fade", "slide", "fade_in_slide_out", "static" }
    stages = "fade_in_slide_out",

    ---@usage Function called when a new window is opened, use for changing win settings/config
    on_open = nil,

    ---@usage Function called when a window is closed
    on_close = nil,

    ---@usage timeout for notifications in ms, default 5000
    timeout = 5000,

    -- Render function for notifications. See notify-render()
    render = "default",

    ---@usage highlight behind the window for stages that change opacity
    background_colour = "Normal",

    ---@usage minimum width for notification windows
    minimum_width = 30,

    ---@usage Icons for the different levels
    icons = {
      ERROR = "",
      WARN = "",
      INFO = "",
      DEBUG = "",
      TRACE = "✎",
    },
  },
}

function M.setup()
  if #vim.api.nvim_list_uis() == 0 then
    -- no need to configure notifications in headless
    return
  end

  local is_loaded, notify = pcall(require, "notify")
  if not is_loaded then
    Log:error "'notify' was required but not loaded"
    return
  end

  notify.setup(options)
  vim.notify = notify
  Log:configure_notifications(notify)
end

return M
