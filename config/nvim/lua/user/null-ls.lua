local M = {}

M._cspell_config = {
  cspell_config_dirs = { "~/.config/cspell/" },
}

M.setup = function(lsp_config)
  local null_ls = require("null-ls")

  local fmt = null_ls.builtins.formatting
  local lint = null_ls.builtins.diagnostics
  local action = null_ls.builtins.code_actions

  local cspell = require("cspell")

  local sources = {
    -- LINTING:
    lint.actionlint,
    lint.terraform_validate,
    lint.golangci_lint,
    cspell.diagnostics.with({ config = M._cspell_config }),
    -- FORMATTING:
    fmt.stylua,
    require("none-ls.formatting.golangci_lint"),
    fmt.ocamlformat,
    fmt.shfmt,
    fmt.terraform_fmt,
    -- ACTIONS:
    action.gomodifytags.with({
      args = { "-quiet", "-transform camelcase", "--skip-unexported" },
    }),
    cspell.code_actions.with({ config = M._cspell_config }),
  }

  null_ls.setup(vim.tbl_deep_extend("force", lsp_config, { sources = sources }))
end

return M
