local M = {}

M.setup = function(lsp_config)
  local is_loaded, rust = pcall(require, "rust-tools")
  if not is_loaded then
    require("nieomylnieja.lib.log"):error "'rust-tools' was required but not loaded"
    return
  end

  local opts = {
    tools = {
      autoSetHints = true,
      inlay_hints = {
        show_parameter_hints = false,
        parameter_hints_prefix = "",
        other_hints_prefix = "",
      },
    },
    server = lsp_config {
      standalone = true,
      ["rust-analyzer"] = {
        checkOnSave = {
          command = "clippyz",
        },
      },
    },
    dap = {
      adapter = require("nieomylnieja.debugger.lldb").adapter,
    },
  }

  rust.setup(opts)
end

return M
