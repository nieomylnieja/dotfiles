local lualine = require("lualine")

-- Config
local config = {
	options = {
		section_separators = "",
		component_separators = "",
		theme = "nord",
		disabled_filetypes = {
			statusline = { "neo-tree" },
		},
	},
	sections = {
		lualine_a = { "mode" },
		lualine_b = {
			"branch",
			{
				"diff",
				-- Is it me or the symbol for modified is really weird
				symbols = { added = " ", modified = "柳 ", removed = " " },
				diff_color = {
					added = { fg = "#A3BE8C" },
					modified = { fg = "#D08770" },
					removed = { fg = "#BF616A" },
				},
			},
			{
				"diagnostics",
				sources = { "nvim_lsp", "nvim_diagnostic" },
				-- Displays diagnostics for the defined severity types
				sections = { "error", "warn", "info", "hint" },
				diagnostics_color = {
					color_error = { fg = "#BF616A" },
					color_warn = { fg = "#EBCB8B" },
					color_info = { fg = "#88C0D0" },
				},
			},
		},
		lualine_c = { "filename" },
		lualine_x = { "encoding", "filetype" },
		lualine_y = { "progress" },
		lualine_z = { "location" },
	},
}

-- Inserts a component in lualine_{section}.
local function ins_section(section, component)
	table.insert(config.sections["lualine_" .. section], component)
end

ins_section("x", {
	-- Lsp server name.
	function()
		local msg = "None"
		local buf_ft = vim.api.nvim_buf_get_option(0, "filetype")
		local clients = vim.lsp.get_active_clients()
		if next(clients) == nil then
			return msg
		end
		for _, client in ipairs(clients) do
			local filetypes = client.config.filetypes
			if filetypes and vim.fn.index(filetypes, buf_ft) ~= -1 then
				return client.name
			end
		end
		return msg
	end,
	icon = " LSP:",
})

-- Now don't forget to initialize lualine
lualine.setup(config)
