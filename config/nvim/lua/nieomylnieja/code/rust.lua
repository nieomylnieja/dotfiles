local M = {}

M.setup = function()
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
    server = {
      on_attach = function(_, bufnr)
        -- Hover actions
        vim.keymap.set("n", "<C-space>", rust.hover_actions.hover_actions, { buffer = bufnr })
        -- Code action groups
        vim.keymap.set("n", "<Leader>a", rust.code_action_group.code_action_group, { buffer = bufnr })
      end,
      ["rust-analyzer"] = {
        checkOnSave = {
          command = "clippy",
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
