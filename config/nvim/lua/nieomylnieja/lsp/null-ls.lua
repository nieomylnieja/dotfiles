local is_loaded, null_ls = pcall(require, "null-ls")
if not is_loaded then
  return
end

local fmt = null_ls.builtins.formatting
local lint = null_ls.builtins.diagnostics
local action = null_ls.builtins.code_actions
local hover = null_ls.builtins.hover

local sources = {
  -- FORMATTING:

  -- Jack of all trades
  fmt.eslint_d,
  -- Protobuf
  fmt.buf,
  -- Python
  fmt.autopep8,
  -- Lua
  fmt.stylua,
  -- Go
  fmt.gofmt,
  fmt.goimports,
  fmt.golines.with { extra_args = { "-m", "120" } },
  -- Shell
  fmt.shfmt,
  -- Terraform
  fmt.terraform_fmt,
  -- All types
  fmt.trim_newlines,
  fmt.trim_whitespace,

  -- LINTING:

  -- Jack of all trades
  lint.eslint_d,
  -- Protobuf
  lint.buf,
  -- Makefile
  lint.checkmake, -- NOTE: Manual installation
  -- Git commit
  lint.gitlint,
  -- All types, spelling
  -- lint.cspell, -- TODO: Configure it only for projects with cspell.json
  -- Go
  lint.golangci_lint,
  -- Dockerfile
  lint.hadolint,
  -- Shell
  lint.shellcheck,
  -- YAML
  lint.yamllint,

  -- ACTIONS:

  -- Shell
  action.shellcheck,
  -- git
  action.gitsigns,
  -- All things JS
  action.eslint_d,
  -- All types, spelling
  -- action.cspell, -- TODO: Configure it only for projects with cspell.json

  -- HOVER:

  -- Shell
  hover.printenv,
}

null_ls.setup { sources = sources }

-- Custom
local custom = require "nieomylnieja.lsp.null-ls-custom"
-- Terraform
null_ls.register(custom.tflint)
