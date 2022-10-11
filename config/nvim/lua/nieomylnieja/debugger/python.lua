local M = {}

M.setup = function(dap)
  dap.adapters.python = {
    type = "executable",
    command = "python",
    args = { "-m", "debugpy.adapter" },
  }

  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = "Launch file",
      program = "${file}",
      pythonPath = function()
        local venv_path = vim.fn.getenv "VIRTUAL_ENVIRONMENT"
        if venv_path ~= vim.NIL and venv_path ~= "" then
          return venv_path .. "/bin/python"
        else
          return "/usr/bin/python"
        end
      end,
    },
  }
end

return M
