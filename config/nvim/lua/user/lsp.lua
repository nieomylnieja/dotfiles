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

local ocamlformat = {
  formatCommand = "ocamlformat",
  formatStdin = true,
}

local languages = {
  lua = { stylua, luacheck },
  go = { goimports },
  ocaml = { ocamlformat },
  -- python = {  },
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
          compositeLiteralTypes = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
        codelenses = {
          generate = true,  -- show the `go generate` lens.
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
          -- { uri = "https://json.schemastore.org/package-lock.json" },
          -- { uri = "https://json.schemastore.org/yarn.lock" },
        }
      }
    }
  },
  ruff_lsp = {},
  pyright = {
    settings = {
      python = {
        analysis = {
          -- We want to rely on ruff diagnostics, having both creates duplicates.
          ignore = { "*" },
        }
      }
    }
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
          }
        }
      }
    }
  },
}

local function keymap(bufnr)
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
  nmap("gr", function()
    ts.lsp_references({ include_declaration = false })
  end, "[G]oto [R]eferences")
  nmap("<leader>ds", ts.lsp_document_symbols, "[D]ocument [S]ymbols")
  nmap("<leader>ws", ts.lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")
  nmap("<leader>fm", vim.lsp.buf.format, "[F]or[M]at buffer")
  nmap("K", vim.lsp.buf.hover, "Hover Documentation")
  nmap("gK", vim.lsp.buf.signature_help, "Signature Documentation")
  nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
  nmap("<leader>D", ts.lsp_type_definitions, "Type [D]efinition")
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

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  capabilities = vim.tbl_deep_extend(
    "force",
    capabilities,
    require("cmp_nvim_lsp").default_capabilities(capabilities))

  local get_on_attach = function(server)
    return function(client, bufnr)
      if server == "gopls" then
        -- Remove poorly supported tokens.
        for i, item in ipairs(capabilities.textDocument.semanticTokens.tokenTypes) do
          if item == "type" then
            table.remove(capabilities.textDocument.semanticTokens.tokenTypes, i)
            break
          end
        end
      end
      if server == "ruff_lsp" then
        client.server_capabilities.hoverProvider = false
      end
      keymap(bufnr)
    end
  end

  for server, config in pairs(servers) do
    require("lspconfig")[server].setup(vim.tbl_deep_extend(
      "force",
      {
        capabilities = capabilities,
        on_attach = get_on_attach(server),
      },
      config))
  end
end

return M
