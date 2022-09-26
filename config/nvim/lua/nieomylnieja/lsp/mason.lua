require("mason").setup()

-- LSP servers
require("mason-lspconfig").setup({
	ensure_installed = {
		"awk_ls",
		"bashls",
		"pyright",
		"gopls",
		"sumneko_lua",
    "terraform-ls",
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
		"buf",
		"yamllint",
		"hadolint",
    "tflint",
		-- Formatters
		"stylua",
		"goimports",
		"golines",
		"shfmt",
		"black",
		"buf",
		"prettier",
	},
	auto_update = true,
	run_on_start = true,
	start_delay = 3000,
})