local M = {}

function M.setup()
  local sources = {
    linters = {
      -- { name = "shellcheck" }, -- already handled by bashls
      { name = "ansiblelint" },
      { name = "flake8" },
    },
    formatters = {
      {
        name = "terraform_fmt",
        filetypes = { "terraform", "tf", "hcl", "terraform-vars" }
      },
      { name = "taplo",      args = { "format", "-" } },
      { name = "autoflake" },
      { name = "isort" },
      { name = "gofumpt" },
      { name = "goimports" },
      { name = "ocamlformat" }, -- Already installed.
    },
    code_actions = {
      { name = "shellcheck" },
      { name = "gomodifytags" },
      { name = "impl" },
    }
  }

  require "lvim.lsp.null-ls.linters".setup(sources.linters)
  require "lvim.lsp.null-ls.formatters".setup(sources.formatters)
  require "lvim.lsp.null-ls.code_actions".setup(sources.code_actions)

  local installer = require("user.mason")
  vim.list_extend(installer.ensure_installed, {
    "shellcheck",
    "ansible-lint",
    "taplo",
    "flake8",
    "autoflake",
    "isort",
    "gomodifytags",
    "impl",
    "gofumpt",
    "goimports",
  })
end

return M
