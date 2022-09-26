local is_loaded, null_ls = pcall(require, "null-ls")
if not is_loaded then
	return
end

local fmt = null_ls.builtins.formatting
local lint = null_ls.builtins.diagnostics
local action = null_ls.builtins.code_actions
local hover = null_ls.builtins.hover

local sources = {
	-- FORMATTING:

	-- Protobuf
	fmt.buf,
	-- Python
	fmt.black.with({ extra_args = { "--fast" } }),
	-- JS, json, yaml and more
	fmt.prettier.with({ extra_args = { "--no-semi" } }),
	-- Lua
	fmt.stylua,
	-- Go
	fmt.gofmt,
	fmt.goimports,
	fmt.golines.with({ extra_args = { "-m", "120" } }),
	-- Tex
	fmt.latexindent,
	-- Markdown
	fmt.remark, -- NOTE: Manual installation
	-- Shell
	fmt.shfmt,
	-- Terraform
	fmt.terraform_fmt,
	-- All types
	fmt.trim_newlines,
	fmt.trim_whitespace,

	-- LINTING:

	-- Protobuf
	lint.buf,
	-- Makefile
	lint.checkmake, -- NOTE: Manual installation
	-- Git commit
	-- lint.commitlint, -- NOTE: Manual installation
	-- All types, spelling
	-- lint.cspell, -- TODO: Configure it only for projects with cspell.json
	-- Go
	lint.golangci_lint,
	-- Dockerfile
	lint.hadolint,
	-- Shell
	lint.shellcheck,
	-- Markdown and Tex
	lint.vale,
	-- YAML
	lint.yamllint,

	-- ACTIONS:

	-- Shell
	action.shellcheck,
	-- git
	action.gitsigns,

	-- HOVER:

	-- Shell
	hover.printenv,
}

null_ls.setup({ sources = sources })

-- Custom
local custom = require("nieomylnieja.lsp.null-ls-custom")
-- Terraform
null_ls.register(custom.tflint)
