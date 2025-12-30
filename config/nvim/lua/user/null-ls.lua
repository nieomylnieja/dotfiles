local M = {}

local cspell_config_files = {
  "cspell.json",
  "cspell.yaml",
  "cspell.yml",
  ".cspell.json",
  ".cspell.yaml",
  ".cspell.yml",
}

M.setup = function(lsp_config)
  local null_ls = require("null-ls")
  local cspell = require("cspell")

  local fmt = null_ls.builtins.formatting
  local lint = null_ls.builtins.diagnostics
  local action = null_ls.builtins.code_actions

  local cspell_condition = function(utils)
    return utils.root_has_file(cspell_config_files)
  end

  local sources = {
    -- LINTING:
    lint.actionlint,
    lint.terraform_validate,
    cspell.diagnostics.with({
      condition = cspell_condition,
      diagnostics_postprocess = function(diagnostic)
        diagnostic.severity = vim.diagnostic.severity.HINT
      end,
    }),
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
    cspell.code_actions.with({ condition = cspell_condition }),
  }

  null_ls.setup(vim.tbl_deep_extend("force", lsp_config, { sources = sources }))
end

return M
