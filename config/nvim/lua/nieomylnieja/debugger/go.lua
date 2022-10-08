local M = {}

M.setup = function()
  local is_loaded, dap = pcall(require, "dap-go")
  if not is_loaded then
    require("nieomylnieja.lib.log"):error "`dap-go` was require but no loaded"
    return
  end
  dap.setup()
end

return M
