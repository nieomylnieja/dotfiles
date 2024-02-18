local M = {}

local servers = {
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
            [vim.fn.expand("$VIMRUNTIME/lua")] = true,
            [vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
            [vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy"] = true,
          },
          maxPreload = 100000,
          preloadFileSize = 10000,
          checkThirdParty = false,
        },
        telemetry = { enable = false },
      },
    },
  },
  gopls = {
    init_options = {
      usePlaceholders = true,
    },
    settings = {
      gopls = {
        experimentalPostfixCompletions = true,
        usePlaceholders = false,
        staticcheck = true,
        -- Remove poorly supported tokens.
        -- For example, currently gopls does not allow to discern between a boolean and a variable...
        semanticTokens = false,
        completeUnimported = true,
        -- Symbols are important for things like goimpl.
        symbolMatcher = "FastFuzzy",
        symbolStyle = "Package",
        symbolScope = "all",
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
          compositeLiteralTypes = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        codelenses = {
          -- We're using neotest for that.
          -- test = true,
          generate = true,
          gc_details = true,
          test = true,
          tidy = true,
          vendor = true,
          regenerate_cgo = true,
          run_govulncheck = true,
          upgrade_dependency = true,
        },
      },
    },
  },
  ocamllsp = {
    single_file_support = true,
  },
  jsonls = {},
  yamlls = {
    settings = {
      yaml = {
        format = {
          enable = true,
        },
        schemas = {
          ["https://taskfile.dev/schema.json"] = "Taskfile.yml",
        },
      },
    },
  },
  ruff_lsp = {},
  pyright = {
    settings = {
      python = {
        analysis = {
          -- We want to rely on ruff diagnostics, having both creates duplicates.
          ignore = { "*" },
        },
      },
    },
  },
  tsserver = {},
  -- Installed through `nix profile install github:oxalica/nil`.
  nil_ls = {
    settings = {
      ["nil"] = {
        formatting = {
          command = { "nixpkgs-fmt" },
        },
        nix = {
          flake = {
            autoArchive = true,
          },
        },
      },
    },
  },
}

local function keymap(bufnr, server)
  local ts = require("telescope.builtin")
  -- See `:help vim.lsp.*` for documentation on any of the below functions
  local nmap = function(keys, func, desc)
    if desc then
      desc = "LSP: " .. desc
    end
    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
  end

  nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
  nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
  nmap("<leader>cl", vim.lsp.codelens.run, "[C]ode [L]ens")
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

  if server == "gopls" then
    nmap("<leader>im", function()
      require("telescope").extensions.goimpl.goimpl({
        path_display = "hidden",
        symbol_width = 60,
      })
    end, "Type [D]efinition")
  end
end

M.setup = function()
  require("mason").setup()
  require("neodev").setup()

  for _, sign in ipairs({
    { name = "DiagnosticSignError", text = "" },
    { name = "DiagnosticSignWarn", text = "" },
    { name = "DiagnosticSignHint", text = "" },
    { name = "DiagnosticSignInfo", text = "" },
  }) do
    vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
  end

  local capabilities = require("cmp_nvim_lsp").default_capabilities()

  local get_on_attach = function(server)
    return function(client, bufnr)
      if server == "ruff_lsp" then
        client.server_capabilities.hoverProvider = false
      end
      keymap(bufnr, server)
    end
  end

  require("user.null-ls").setup({
    capabilities = capabilities,
    on_attach = get_on_attach(),
  })

  for server, config in pairs(servers) do
    require("lspconfig")[server].setup(vim.tbl_deep_extend("force", {
      capabilities = capabilities,
      on_attach = get_on_attach(server),
    }, config))
  end
end

return M
