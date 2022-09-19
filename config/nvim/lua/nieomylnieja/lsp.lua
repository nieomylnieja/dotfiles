local lsp = require("lspconfig")
local util = require("lspconfig/util")
local nnoremap = require("nieomylnieja.keymap").nnoremap

-- Mappings.
-- See `:help vim.diagnostic.*` for documentation on any of the below functions
local opts = { noremap = true, silent = true }
nnoremap("<space>e", vim.diagnostic.open_float, opts)
nnoremap("[d", vim.diagnostic.goto_prev, opts)
nnoremap("]d", vim.diagnostic.goto_next, opts)
nnoremap("<space>q", vim.diagnostic.setloclist, opts)

-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
	-- Enable completion triggered by <c-x><c-o>
	vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

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
end

-- Python
lsp.pyright.setup({
	on_attach = on_attach,
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
	single_file_support = true,
})
-- Golang
lsp.gopls.setup({
	on_attach = on_attach,
	cmd = { "gopls" },
	filetypes = { "go", "gomod", "gotmpl" },
	root_dir = util.root_pattern("go.mod", ".git"),
	single_file_support = true,
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
})
-- AWK
lsp.awk_ls.setup({
	on_attach = on_attach,
	cmd = { "awk-language-server" },
	filetypes = { "awk" },
	single_file_support = true,
})
-- Bash
lsp.bashls.setup({
	on_attach = on_attach,
	cmd = { "bash-language-server", "start" },
	cmd_env = {
		GLOB_PATTERN = "*@(.sh|.inc|.bash|.command)",
	},
	filetypes = { "sh" },
	root_dir = util.find_git_ancestor,
	single_file_support = true,
})
