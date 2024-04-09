local M = {}

M.setup = function(lsp_config)
  local null_ls = require("null-ls")

  local fmt = null_ls.builtins.formatting
  local lint = null_ls.builtins.diagnostics
  local action = null_ls.builtins.code_actions

  local sources = {
    -- FORMATTING:
    -- Lua
    fmt.stylua,
    -- Go
    fmt.goimports,
    -- OCaml
    fmt.ocamlformat,
    -- Shell
    fmt.shfmt,
    -- All types

    -- ACTIONS:
    -- custom.gomodifytags(),
    action.gomodifytags.with({
      args = { "-quiet", "-transform camelcase", "--skip-unexported" },
    }),
  }

  null_ls.setup(vim.tbl_deep_extend("force", lsp_config, { sources = sources }))
end

return M
