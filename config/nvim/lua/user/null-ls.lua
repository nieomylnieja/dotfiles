local M = {}

M.setup = function(lsp_config)
  local null_ls = require("null-ls")

  local fmt = null_ls.builtins.formatting
  local lint = null_ls.builtins.diagnostics
  local action = null_ls.builtins.code_actions

  local sources = {
    -- LINTING:
    lint.actionlint,
    lint.terraform_validate,
    lint.golangci_lint,
    --
    -- FORMATTING:
    -- Lua
    fmt.stylua,
    -- Go
    -- FIXME: goimports is not working properly, it lags the hell out of null-ls formatting.
    -- fmt.goimports,
    -- OCaml
    fmt.ocamlformat,
    fmt.shfmt,
    fmt.terraform_fmt,
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
