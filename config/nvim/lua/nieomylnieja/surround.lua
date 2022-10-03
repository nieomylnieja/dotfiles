local M = {}

local Log = require "nieomylnieja.lib.log"

M.setup = function()
  local is_loaded, surround = pcall(require, "nvim-surround")
  if not is_loaded then
    Log:error "'nvim-surround' was required but not loaded"
    return
  end

  surround.setup {
    keymaps = {
      insert = "<C-g>s",
      insert_line = "<C-g>S",
      normal = "ys",
      normal_cur = "yss",
      normal_line = "yS",
      normal_cur_line = "ySS",
      visual = "S",
      visual_line = "gS",
      delete = "ds",
      change = "cs",
    },
  }
end

return M
