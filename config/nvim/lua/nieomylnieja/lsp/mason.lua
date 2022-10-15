local M = {}

M.path = table.concat({ vim.fn.stdpath "data", "mason" }, "/")

M.setup = function()
  local lp = require("nieomylnieja.lib.functions").load_plugin
  local mason = lp "mason"
  local mason_lsp = lp "mason-lspconfig"
  local mason_installer = lp "mason-tool-installer"
  if not (mason and mason_lsp and mason_installer) then
    return
  end

  mason.setup {
    install_root_dir = M.path,
  }

  -- LSP servers
  mason_lsp.setup {
    ensure_installed = {
      "awk_ls",
      "bashls",
      "pyright",
      "gopls",
      "sumneko_lua",
      "terraform-ls",
      "texlab",
      "yaml-language-server",
    },
  }

  mason_installer.setup {
    ensure_installed = {
      -- DAP
      "delve",
      "debugpy",
      "bash-debug-adapter",
      "codelldb",
      -- Linters
      "golangci-lint",
      "shellcheck",
      "cspell",
      "buf",
      "yamllint",
      "hadolint",
      "tflint",
      "eslint_d",
      "proselint",
      -- Formatters
      "stylua",
      "goimports",
      "golines",
      "shfmt",
      "autopep8",
      "buf",
      "taplo",
    },
    auto_update = true,
    run_on_start = true,
    start_delay = 3000,
  }
end

return M
