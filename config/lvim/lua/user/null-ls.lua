local M = {}

local null_ls = require("null-ls")

M._custom_sources = {
  M._split_parameters_code_action,
}

function M.setup()
  for _, src in pairs(M._custom_sources) do
    null_ls.register(src)
  end

  local sources = {
    linters = {
      -- { name = "shellcheck" }, -- handled by bashls
      { name = "ansiblelint" },
      -- { name = "flake8" }, -- handled by pylsp
      { name = "statix" },
    },
    formatters = {
      {
        name = "terraform_fmt",
        filetypes = { "terraform", "tf", "hcl", "terraform-vars" }
      },
      {
        name = "taplo",
        args = { "format", "-" }
      },
      { name = "alejandra" },
      { name = "autoflake" },
      { name = "isort" },
      { name = "gofumpt" },
      { name = "goimports" },
      { name = "ocamlformat" }, -- Already installed.
      { name = "cue_fmt" },
      { name = "trim_whitespace" },
      { name = "trim_newlines" },
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

M._split_parameters_code_action = {
  method = null_ls.methods.DIAGNOSTICS,
  filetypes = { "markdown", "text" },
  generator = {
    fn = function(params)
      local diagnostics = {}
      -- sources have access to a params object
      -- containing info about the current file and editor state
      for i, line in ipairs(params.content) do
        local col, end_col = line:find("really")
        if col and end_col then
          -- null-ls fills in undefined positions
          -- and converts source diagnostics into the required format
          table.insert(diagnostics, {
            row = i,
            col = col,
            end_col = end_col + 1,
            source = "split_parameters",
            message = "Split parameters!",
            severity = vim.diagnostic.severity.WARN,
          })
        end
      end
      return diagnostics
    end,
  },
}

return M
