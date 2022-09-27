local M = {}

local Log = require "nieomylnieja.lib.log"

M.setup = function()
  local is_loaded, hop = pcall(require, "hop")
  if not is_loaded then
    Log:error "`hop` was required but not loaded"
    return
  end
  hop.setup()
  -- TODO: Use nord colors.
  vim.cmd([[hi HopNextKey guifg=#88C0D0]])
  vim.cmd([[hi HopNextKey1 guifg=#88C0D0]])
  vim.cmd([[hi HopNextKey2 guifg=#88C0D0]])
end

return M
