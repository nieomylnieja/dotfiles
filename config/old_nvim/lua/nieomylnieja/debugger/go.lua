local M = {}

M.load = function(_)
  local is_loaded, go = pcall(require, "dap-go")
  if not is_loaded then
    require("nieomylnieja.lib.log"):error "`dap-go` was require but no loaded"
    return
  end
  go.setup()
end

return M
