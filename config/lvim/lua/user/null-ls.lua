local M = {}

local registry = require("mason-registry")

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
      { name = "taplo",    args = { "format", "-" } },
      { name = "autoflake" },
      { name = "isort" },
    },
    code_actions = {
      { name = "shellcheck" },
    }
  }

  require "lvim.lsp.null-ls.linters".setup(sources.linters)
  require "lvim.lsp.null-ls.formatters".setup(sources.formatters)
  require "lvim.lsp.null-ls.code_actions".setup(sources.code_actions)

  local installer = require("user.mason")
  vim.tbl_extend("keep", installer.ensure_installed, {
    "shellcheck",
    "ansible-lint",
    "taplo",
    "flake8",
    "autoflake",
    "isort",
  })
end

return M
