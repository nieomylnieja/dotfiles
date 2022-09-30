local M = {}

local Log = require("nieomylnieja.lib.log")

local is_loaded, dap = pcall(require, "dap-go")
if not is_loaded then
  Log:error("`dap-go` was require but no loaded")
  return
end

M.setup = function ()
  dap.setup()
end

return M
