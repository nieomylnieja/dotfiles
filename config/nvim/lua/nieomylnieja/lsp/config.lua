local nnoremap = require("nieomylnieja.keymap").nnoremap

local lsp = require("lspconfig")
local cmp_lsp = require("cmp_nvim_lsp")

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true

local function config(_config)
	return vim.tbl_deep_extend("force", {
		capabilities = cmp_lsp.update_capabilities(vim.lsp.protocol.make_client_capabilities()),
		-- Use an on_attach function to only map the following keys
		-- after the language server attaches to the current buffer
		on_attach = function()
			-- Mappings.
			-- See `:help vim.lsp.*` for documentation on any of the below functions
			local bufopts = { noremap = true, silent = true, buffer = bufnr }
			nnoremap("gD", vim.lsp.buf.declaration, bufopts)
			nnoremap("gd", vim.lsp.buf.definition, bufopts)
			nnoremap("K", vim.lsp.buf.hover, bufopts)
			nnoremap("gi", vim.lsp.buf.implementation, bufopts)
			nnoremap("<C-k>", vim.lsp.buf.signature_help, bufopts)
			nnoremap("<space>wa", vim.lsp.buf.add_workspace_folder, bufopts)
			nnoremap("<space>wr", vim.lsp.buf.remove_workspace_folder, bufopts)
			nnoremap("<space>wl", function()
				print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
			end, bufopts)
			nnoremap("<space>D", vim.lsp.buf.type_definition, bufopts)
			nnoremap("<space>rn", vim.lsp.buf.rename, bufopts)
			nnoremap("<space>ca", vim.lsp.buf.code_action, bufopts)
			nnoremap("gr", vim.lsp.buf.references, bufopts)
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
