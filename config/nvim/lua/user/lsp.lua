local M = {}

local stylua = {
  formatCommand = "stylua -s --stdin-filepath ${INPUT} -",
  formatStdin = true,
}

local luacheck = {
  lintCommand = "luacheck --codes --formatter plain --std luajit --globals vim --filename ${INPUT} -",
  lintIgnoreExitCode = true,
  lintStdin = true,
  lintFormats = { "%f:%l:%c: %m" },
  lintSource = "luacheck"
}

local goimports = {
  formatCommand = "goimports",
  formatStdin = true,
}

local languages = {
  lua = { stylua, luacheck },
  go = { goimports },
}

local servers = {
  efm = {
    settings = {
      rootMarkers = { ".git/" },
      lintDebounce = 100,
      languages = languages,
    },
    root_dir = vim.loop.cwd,
    filetypes = vim.tbl_keys(languages),
  },
  lua_ls = {
    settings = {
      Lua = {
        runtime = {
          version = "LuaJIT",
        },
        diagnostics = {
          globals = { "vim" },
          disable = {
            "missing-fields",
            "incomplete-signature-doc",
          },
        },
        workspace = {
          library = {
            [vim.fn.expand "$VIMRUNTIME/lua"] = true,
            [vim.fn.expand "$VIMRUNTIME/lua/vim/lsp"] = true,
            [vim.fn.stdpath "data" .. "/lazy/lazy.nvim/lua/lazy"] = true,
          },
          maxPreload = 100000,
          preloadFileSize = 10000,
          checkThirdParty = false,
        },
        telemetry = { enable = false },
      },
    }
  },
  gopls = {
    settings = {
      gopls = {
        usePlaceholders = false,
        staticcheck = true,
        semanticTokens = true,
        completeUnimported = true,
        analyses = {
          unreachable = true,
          nilness = true,
          shadow = true,
          unusedparams = true,
          unusewrites = true,
        },
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        codelenses = {
          generate = true,   -- show the `go generate` lens.
          gc_details = true, -- Show a code lens toggling the display of gc's choices.
          test = true,
          tidy = true,
          vendor = true,
          regenerate_cgo = true,
          upgrade_dependency = true,
        }
      }
    }
  },
}

local function keymap(bufnr)
  local ts = require("telescope.builtin")
  -- TODO: here
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local nmap = function(keys, func, desc)
    if desc then
      desc = "LSP: " .. desc
    end
    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
  end

  nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
  nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
  nmap("gd", ts.lsp_definitions, "[G]oto [D]efinition")
  nmap("gi", ts.lsp_implementations, "[G]oto [I]mplementation")
  nmap("gr", ts.lsp_references, "[G]oto [R]eferences")
  nmap("<leader>ds", ts.lsp_document_symbols, "[D]ocument [S]ymbols")
  nmap("<leader>ws", ts.lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
  nmap("<leader>fm", vim.lsp.buf.format, "[F]or[M]at buffer")
  nmap("K", vim.lsp.buf.hover, "Hover Documentation")
  nmap("gK", vim.lsp.buf.signature_help, "Signature Documentation")
  nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
  nmap("<leader>D", ts.lsp_type_definitions, "Type [D]efinition")
end

M.setup = function()
  -- mason-lspconfig requires that these setup functions are called in this order
  -- before setting up the servers.
  require("mason").setup()
  require("mason-lspconfig").setup()
  require("neodev").setup()

  for _, sign in ipairs({
    { name = "DiagnosticSignError", text = "" },
    { name = "DiagnosticSignWarn", text = "" },
    { name = "DiagnosticSignHint", text = "" },
    { name = "DiagnosticSignInfo", text = "" },
  }) do
    vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
  end

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = vim.tbl_deep_extend(
    "force",
    capabilities,
    require("cmp_nvim_lsp").default_capabilities(capabilities))
  -- Ensure the servers above are installed
  local mason_lspconfig = require "mason-lspconfig"

  mason_lspconfig.setup {
    ensure_installed = vim.tbl_keys(servers),
  }
  local on_attach = function(_, bufnr)
    keymap(bufnr)
  end

  mason_lspconfig.setup_handlers {
    function(server_name)
      if server_name == "gopls" then
        -- Remove poorly supported tokens.
        for i, item in ipairs(capabilities.textDocument.semanticTokens.tokenTypes) do
          if item == "type" then
            table.remove(capabilities.textDocument.semanticTokens.tokenTypes, i)
            break
          end
        end
      end
      require("lspconfig")[server_name].setup(vim.tbl_deep_extend(
        "force",
        {
          capabilities = capabilities,
          on_attach = on_attach,
        },
        servers[server_name]))
    end,
  }
end

return M
