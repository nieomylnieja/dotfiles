-- Utilities for creating configurations
local util = require("formatter.util")

-- Provides the Format, FormatWrite, FormatLock, and FormatWriteLock commands
require("formatter").setup({
	-- Enable or disable logging
	logging = true,
	-- Set the log level
	log_level = vim.log.levels.WARN,
	-- All formatter configurations are opt-in
	filetype = {
		lua = {
			function()
				return {
					exe = "stylua",
					args = {
						"--search-parent-directories",
						"--stdin-filepath",
						util.escape_path(util.get_current_buffer_file_path()),
						"--",
						"-",
					},
					stdin = true,
				}
			end,
		},
		json = {
			function()
				return { exe = "jq", args = { "." }, stdin = true }
			end,
		},
    -- This is experimental, black is very opinionated, I might hate it...
		python = {
			function()
				return { exe = "black", args = { "-q", "-" }, stdin = true }
			end,
		},
		sh = {
			function()
				local shiftwidth = vim.opt.shiftwidth:get()
				local expandtab = vim.opt.expandtab:get()

				if not expandtab then
					shiftwidth = 0
				end

				return { exe = "shfmt", args = { "-i", shiftwidth }, stdin = true }
			end,
		},
		go = {
			function()
				return { exe = "gofmt", stdin = true }
			end,
			function()
				return { exe = "goimports", stdin = true }
			end,
			function()
				return { exe = "golines", args = { "-m", "120" }, stdin = true }
			end,
		},
		-- Use the special "*" filetype for defining formatter configurations on
		-- any filetype
		["*"] = {
			-- "formatter.filetypes.any" defines default configurations for any
			-- filetype
			require("formatter.filetypes.any").remove_trailing_whitespace,
		},
	},
})
