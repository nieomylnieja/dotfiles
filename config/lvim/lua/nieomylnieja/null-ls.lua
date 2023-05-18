local M = {}

function M.setup()
  sources = {
    linters = {
      {
        name = "shellcheck",
        install = true
      }
    },
    formatters = {
      {
        name = "terraform_fmt",
        filetypes = { "terraform", "tf", "hcl", "terraform-vars" }
      },
      {
        name = "taplo",
        args = { "format", --[[ "--config", "",  ]] "-" },
        install = true
      }
    }
  }

  require "lvim.lsp.null-ls.linters".setup(sources.linters)
  require "lvim.lsp.null-ls.formatters".setup(sources.formatters)

  ensure_installed = {}
  for _, typ in pairs(sources) do
    for _, src in ipairs(typ) do
      if src.install then
        table.insert(ensure_installed, src.name)
      end
    end
  end

  require "mason-null-ls".setup({ ensure_installed = ensure_installed })
end

return M
