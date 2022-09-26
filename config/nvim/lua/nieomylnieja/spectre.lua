local M = {}

local Log = require "nieomylnieja.lib.log"

M.setup = function()
  local is_loaded, spectre = pcall(require, "spectre")
  if not is_loaded then
    Log:error "`spectre` plugin not loaded, but was required"
    return M
  end
  spectre.setup()
end

return M
