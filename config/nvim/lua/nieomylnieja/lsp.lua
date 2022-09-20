-- vim:fdm=marker:fdl=0
local nnoremap = require("nieomylnieja.keymap").nnoremap

-- Completion {{{1

local cmp = require("cmp")
local lspkind = require("lspkind")

local source_mapping = {
	buffer = "[Buffer]",
	nvim_lsp = "[LSP]",
	nvim_lua = "[Lua]",
	cmp_tabnine = "[TN]",
	path = "[Path]",
}

cmp.setup({
	snippet = {
		expand = function(args)
			require("luasnip").lsp_expand(args.body)
		end,
	},
	mapping = cmp.mapping.preset.insert({
		["<tab>"] = cmp.mapping.confirm({ select = true }),
		["<C-u>"] = cmp.mapping.scroll_docs(-4),
		["<C-d>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
	}),
	formatting = {
		format = function(entry, vim_item)
			-- if you have lspkind installed, you can use it like
			-- in the following line:
			vim_item.kind = lspkind.symbolic(vim_item.kind, { mode = "symbol" })
			vim_item.menu = source_mapping[entry.source.name]
			if entry.source.name == "cmp_tabnine" then
				local detail = (entry.completion_item.data or {}).detail
				vim_item.kind = ""
				if detail and detail:find(".*%%.*") then
					vim_item.kind = vim_item.kind .. " " .. detail
				end

				if (entry.completion_item.data or {}).multiline then
					vim_item.kind = vim_item.kind .. " " .. "[ML]"
				end
			end
			local maxwidth = 80
			vim_item.abbr = string.sub(vim_item.abbr, 1, maxwidth)
			return vim_item
		end,
	},

	sources = {
		-- I might give it a try: https://github.com/tzachar/cmp-tabnine#install
		-- { name = "cmp_tabnine" },
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
		{ name = "buffer" },
	},
})

-- LSP mappings {{{1

local lsp = require("lspconfig")
local cmp_lsp = require("cmp_nvim_lsp")

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

-- LSP Configs {{{1

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
  cmd = {sumneko_binary, "-E", sumneko_root_path .. "/main.lua"},
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

-- Other {{{1

require("symbols-outline").setup({
	-- whether to highlight the currently hovered symbol
	-- disable if your cpu usage is higher than you want it
	-- or you just hate the highlight
	-- default: true
	highlight_hovered_item = true,

	-- whether to show outline guides
	-- default: true
	show_guides = true,
})

-- Load snippets
require("luasnip.loaders.from_vscode").lazy_load()
