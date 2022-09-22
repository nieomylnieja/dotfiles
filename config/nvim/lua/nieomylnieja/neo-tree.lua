-- Remove the deprecated commands from v1.x
vim.cmd([[ let g:neo_tree_remove_legacy_commands = 1 ]])

-- Toggle Neotree
require("nieomylnieja.keymap").nnoremap("<leader>n", ":Neotree<cr>", { noremap = true, silent = true })

local tree = require("neo-tree")

local function getTelescopeOpts(state, path)
	return {
		cwd = path,
		search_dirs = { path },
		attach_mappings = function(prompt_bufnr, _)
			local actions = require("telescope.actions")
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local action_state = require("telescope.actions.state")
				local selection = action_state.get_selected_entry()
				local filename = selection.filename
				if filename == nil then
					filename = selection[1]
				end
				-- any way to open the file without triggering auto-close event of neo-tree?
				require("neo-tree.sources.filesystem").navigate(state, state.path, filename)
			end)
			return true
		end,
	}
end

-- The defaults are at: https://github.com/nvim-neo-tree/neo-tree.nvim/blob/main/lua/neo-tree/defaults.lua
tree.setup({
	source = {
		"filesystem",
		"git_status",
	},
	close_if_last_window = true,
	log_level = "warn",
	source_selector = {
		statusline = true,
	},
	window = {
		position = "right",
		width = 30,
	},
	filesystem = {
		follow_current_file = true,
		window = {
			mappings = {
				["o"] = "system_open",
				["tf"] = "telescope_find",
				["tg"] = "telescope_grep",
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
			telescope_find = function(state)
				local node = state.tree:get_node()
				local path = node:get_id()
				require("telescope.builtin").find_files(getTelescopeOpts(state, path))
			end,
			telescope_grep = function(state)
				local node = state.tree:get_node()
				local path = node:get_id()
				require("telescope.builtin").live_grep(getTelescopeOpts(state, path))
			end,
		},
	},
})
