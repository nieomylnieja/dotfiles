local M = {}

local null_ls = require("null-ls")
local h = require("null-ls.helpers")
local methods = require("null-ls.methods")

local DIAGNOSTICS = methods.internal.DIAGNOSTICS

M.tflint = {
	name = "tflint",
	meta = {
		url = "https://github.com/terraform-linters/tflint",
		description = "A pluggable Terraform linter.",
	},
	method = DIAGNOSTICS,
	filetypes = { "terraform", "tf" },
	generator = null_ls.generator({
		command = "tflint",
		args = { "--format", "json", "$FILENAME" },
		to_stdin = true,
		format = "json",
		check_exit_code = function(code)
			return code <= 2
		end,
		on_output = function(params)
			local diags = {}
			local issues = params.output["issues"]
			if type(issues) == "table" then
				for _, d in ipairs(issues) do
					if d.range.filename == params.bufname then
						table.insert(diags, {
							source = string.format("tflint:%s", d.rule.name),
							end_row = d.range.start.line,
							end_col = d.range.start.column,
							row = d.range.start.line,
							col = d.range.start.column,
							message = d.message,
							severity = h.diagnostics.severities["warning"],
						})
					end
				end
			end
			return diags
		end,
	}),
}

return M
