local builtin = require("telescope.builtin")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local scan = require("plenary.scandir")
local themes = require("telescope.themes")

local search_dir = function(opts)
	opts = opts or {}
	pickers
		.new(themes.get_dropdown(opts), {
			prompt_title = "Search directory",
			finder = finders.new_table({
				results = scan.scan_dir(".", { only_dirs = true, respect_gitignore = true }),
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					builtin.live_grep({
						prompt_title = "Live Grep in: " .. selection[1],
						search_dirs = { selection[1] },
					})
				end)
				return true
			end,
		})
		:find()
end

return require("telescope").register_extension({
	exports = {
		live_grep_dir = search_dir,
	},
})
