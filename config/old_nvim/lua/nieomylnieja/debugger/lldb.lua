local M = {}

M.adapter = {
  type = "server",
  port = "${port}",
  executable = {
    command = "codelldb",
    args = { "--port", "${port}" },
  },
}

M.load = function(dap)
  dap.adapters.codelldb = M.adapter

  dap.configurations.cpp = {
    {
      name = "Launch",
      type = "codelldb",
      request = "launch",
      program = function()
        return vim.fn.input("Path to executable: ", vim.loop.cwd() .. "/", "file")
      end,
      cwd = "${workspaceFolder}",
      stopOnEntry = true,
    },
  }

  -- Use it for C and Rust too.
  dap.configurations.c = dap.configurations.cpp
  dap.configurations.rust = dap.configurations.cpp
end

return M
