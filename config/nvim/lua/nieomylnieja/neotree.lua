-- Remove the deprecated commands from v1.x
vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])

local manager = require("neo-tree.sources.manager")

-- The defaults are at: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/lua/neo-tree/defaults.lua
require("neo-tree").setup({
	sources = {
		"filesystem",
		"git_status",
	},
	close_if_last_window = true,
	log_level = "warn",
	window = {
		position = "right",
		width = 30,
	},
	source_selector = {
		statusline = true,
		tab_labels = { -- falls back to source_name if nil
			filesystem = "   ",
			git_status = "   ",
		},
		padding = 0,
		separator = "",
		show_separator_on_edge = false,
		content_layout = "center",
		highlight_tab = "NeoTreeTabInactive",
		highlight_tab_active = "NeoTreeTabActive",
		highlight_background = "NeoTreeTabInactive",
	},
	event_handlers = {
		{
			event = "file_opened",
			handler = function(_)
        manager.close_all()
			end,
		},
	},
	filesystem = {
		hijack_netrw_behavior = "open_default",
		follow_current_file = true,
		window = {
			mappings = {
				["<space>"] = "noop",
				["<tab>"] = "toggle_node",
				["o"] = "system_open",
			},
		},
		commands = {
			system_open = function(state)
				local node = state.tree:get_node()
				local path = node:get_id()
				-- macOs: open file in default application in the background.
				-- Probably you need to adapt the Linux recipe for manage path with spaces. I don't have a mac to try.
				vim.api.nvim_command("silent !open -g " .. path)
				-- Linux: open file in default application
				vim.api.nvim_command(string.format("silent !xdg-open '%s'", path))
			end,
		},
	},
})
