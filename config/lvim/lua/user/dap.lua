local M = {}

function M.setup()
  local mason_path = vim.fn.glob(vim.fn.stdpath "data" .. "/mason/")
  require("dap-python").setup(mason_path .. "packages/debugpy/venv/bin/python")
  require("dap-go").setup()

  local installer = require("user.mason")
  vim.list_extend(installer.ensure_installed, {
    "delve",
  })
end

return M
