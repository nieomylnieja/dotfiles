local M = {}

M.load = function(_)
  local is_loaded, python = pcall(require, "dap-python")
  if not is_loaded then
    require("nieomylnieja.lib.log"):error "'dap-python' was required but not loaded"
    return
  end
  python.setup(require("nieomylnieja.lsp.mason").path .. "/packages/debugpy/venv/bin/python")
end

return M
