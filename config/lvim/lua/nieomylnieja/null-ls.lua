local M = {}

function M.setup()
  local sources = {
    linters = {
      { name = "shellcheck" },
      { name = "ansiblelint" },
    },
    formatters = {
      {
        name = "terraform_fmt",
        filetypes = { "terraform", "tf", "hcl", "terraform-vars" }
      },
      { name = "taplo", args = { "format", "-" } },
    },
    code_actions = {
      { name = "shellcheck" },
    }
  }

  require "lvim.lsp.null-ls.linters".setup(sources.linters)
  require "lvim.lsp.null-ls.formatters".setup(sources.formatters)
  require "lvim.lsp.null-ls.code_actions".setup(sources.code_actions)

  -- TODO: right now mason-null-ls is lacking... once it fully handles all the renames
  -- this can be done automatically.
  local ensure_installed = {
    "shellcheck", "ansible-lint", "taplo"
  }
  require "mason-null-ls".setup({ ensure_installed = ensure_installed })
end

return M
