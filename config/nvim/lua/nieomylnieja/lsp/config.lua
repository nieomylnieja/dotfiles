local nnoremap = require("nieomylnieja.keymap").nnoremap

local lsp = require("lspconfig")
local cmp_lsp = require("cmp_nvim_lsp")
local telescope = require("telescope.builtin")

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

local function config(_config)
	return vim.tbl_deep_extend("force", {
		capabilities = cmp_lsp.update_capabilities(vim.lsp.protocol.make_client_capabilities()),
		-- Use an on_attach function to only map the following keys
		-- after the language server attaches to the current buffer
		on_attach = function(_, bufnr)
			-- Mappings.
			-- See `:help vim.lsp.*` for documentation on any of the below functions
			local nmap = function(keys, func, desc)
				if desc then
					desc = "LSP: " .. desc
				end
				nnoremap(keys, func, { noremap = true, silent = true, buffer = bufnr, desc = desc })
			end

			nmap("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
			nmap("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")

			nmap("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
			nmap("gi", vim.lsp.buf.implementation, "[G]oto [I]mplementation")
			nmap("gr", telescope.lsp_references, "[G]oto [R]eferences")
			nmap("<leader>ds", telescope.lsp_document_symbols, "[D]ocument [S]ymbols")
			nmap("<leader>ws", telescope.lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

			-- See `:help K` for why this keymap
			nmap("K", vim.lsp.buf.hover, "Hover Documentation")
			nmap("<C-k>", vim.lsp.buf.signature_help, "Signature Documentation")

			-- Lesser used LSP functionality
			nmap("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
			nmap("<leader>D", vim.lsp.buf.type_definition, "Type [D]efinition")
			nmap("<leader>wa", vim.lsp.buf.add_workspace_folder, "[W]orkspace [A]dd Folder")
			nmap("<leader>wr", vim.lsp.buf.remove_workspace_folder, "[W]orkspace [R]emove Folder")
			nmap("<leader>wl", function()
				print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end, "[W]orkspace [L]ist Folders")
			-- TODO: Right now I haven't figured out a way to set it only
			-- for LSPs which support native formatting, I might just want
			-- to use 'formatter.nvim' for that anyway as the config is more
			-- sane to me and plain simple...
			-- nnoremap('<space>f', vim.lsp.buf.formatting, bufopts)
		end,
	}, _config or {})
end

local lsputil = require("lspconfig/util")

-- Python
lsp.pyright.setup(config({
	cmd = { "pyright-langserver", "--stdio" },
	filetypes = { "python" },
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				diagnosticMode = "workspace",
				useLibraryCodeForTypes = true,
			},
		},
	},
}))

-- Golang
lsp.gopls.setup(config({
	cmd = { "gopls" },
	filetypes = { "go", "gomod", "gotmpl" },
	root_dir = lsputil.root_pattern("go.mod", ".git"),
	settings = {
		gopls = {
			experimentalPostfixCompletions = true,
			analyses = {
				unusedparams = true,
				shadow = true,
			},
			staticcheck = true,
		},
	},
}))

-- AWK
lsp.awk_ls.setup(config({
	cmd = { "awk-language-server" },
	filetypes = { "awk" },
}))

-- Bash
lsp.bashls.setup(config({
	cmd = { "bash-language-server", "start" },
	cmd_env = {
		GLOB_PATTERN = "*@(.sh|.inc|.bash|.command)",
	},
	filetypes = { "sh" },
	root_dir = lsputil.find_git_ancestor,
}))

-- Lua
local sumneko_root_path = os.getenv("DOTFILES") .. "/clones/lua-language-server"
local sumneko_binary = sumneko_root_path .. "/bin/lua-language-server"

lsp.sumneko_lua.setup(config({
	cmd = { sumneko_binary, "-E", sumneko_root_path .. "/main.lua" },
	filetypes = { "lua" },
	settings = {
		Lua = {
			runtime = {
				-- Tell the language server which version of Lua you're using (most likely LuaJIT in the case of Neovim)
				version = "LuaJIT",
				-- Setup your lua path
				path = vim.split(package.path, ";"),
			},
			diagnostics = {
				-- Get the language server to recognize the `vim` global
				globals = { "vim" },
			},
			workspace = {
				-- Make the server aware of Neovim runtime files
				library = {
					[vim.fn.expand("$VIMRUNTIME/lua")] = true,
					[vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
				},
			},
		},
	},
}))
