lvim.lsp.installer.setup.automatic_installation = false

lvim.lsp.installer.setup.ensure_installed = {
  "lua_ls",
  "jsonls",
  "yamlls",
  "gopls",
  "bashls",
  "pylsp",
  "terraformls",
  "dockerls",
  "tsserver",
  "taplo",
  "ansiblels",
  -- "ocamllsp", -- It's better to get one manually for prefered opam switch.
}

-- Configure a server manually. !!Requires `:LvimCacheReset` to take effect!!
local manager = require("lvim.lsp.manager")
local server_overrides = {
  ["taplo"] = { filetypes = { "toml" } }
}
for server, opts in pairs(server_overrides) do
  table.insert(lvim.lsp.automatic_configuration.skipped_servers, server)
  manager.setup(server, opts)
end

-- custom on_attach function that will be used for all the language servers
-- See <https://github.com/neovim/nvim-lspconfig#keybindings-and-completion>
lvim.lsp.on_attach_callback = function(client, bufnr)
  local function buf_set_option(...)
    vim.api.nvim_buf_set_option(bufnr, ...)
  end

  --Enable completion triggered by <c-x><c-o>
  buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")
  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype == "helm" then
    vim.diagnostic.disable(bufnr)
    vim.defer_fn(function()
      vim.diagnostic.reset(nil, bufnr)
    end, 1000)
  end
end
