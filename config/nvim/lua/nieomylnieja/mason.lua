require("mason").setup()

-- LSP servers
require("mason-lspconfig").setup({
	ensure_installed = {
		"awk_ls",
		"bashls",
		"pyright",
		"gopls",
		"sumneko_lua",
	},
})

require("mason-tool-installer").setup({
	ensure_installed = {
		-- DAP
		"delve",
		-- Linters
		"golangci-lint",
		"shellcheck",
		"vale",
		"cspell",
		-- Formatters
		"stylua",
		"goimports",
		"golines",
		"luacheck",
		"shfmt",
		"jq",
		"black",
	},
	auto_update = false,
	run_on_start = true,
	start_delay = 3000,
})
