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
    "texlab",
	},
})

require("mason-tool-installer").setup({
	ensure_installed = {
		-- DAP
		"delve",
		-- Linters
		"golangci-lint",
		"shellcheck",
		"cspell",
		"buf",
		"yamllint",
		"hadolint",
    "tflint",
    "eslint_d",
		-- Formatters
		"stylua",
		"goimports",
		"golines",
		"shfmt",
    "autopep8",
		"buf",
	},
	auto_update = true,
	run_on_start = true,
	start_delay = 3000,
})
