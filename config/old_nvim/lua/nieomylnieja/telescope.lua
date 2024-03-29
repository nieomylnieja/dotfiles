local nnoremap = require("nieomylnieja.keymap").nnoremap
local telescope = require "telescope"
local builtin = require "telescope.builtin"

nnoremap("<leader>ff", builtin.find_files)
nnoremap("<leader>fg", builtin.live_grep)
nnoremap("<leader>fb", builtin.buffers)
nnoremap("<leader>fh", builtin.help_tags)
nnoremap("<leader>fc", builtin.git_branches)
nnoremap("<leader>ft", builtin.treesitter)
nnoremap("<leader>fr", builtin.command_history)

telescope.setup {
  defaults = {
    mappings = {
      i = {
        -- map actions.which_key to <C-h> (default: <C-/>)
        -- actions.which_key shows the mappings for your picker,
        -- e.g. git_{create, delete, ...}_branch for the git_branches picker
        ["<C-h>"] = "which_key",
      },
    },
  },
  pickers = {
    find_files = {
      find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true, -- false will only do exact matching
      override_generic_sorter = true, -- override the generic sorter
      override_file_sorter = true, -- override the file sorter
      case_mode = "smart_case", -- or "ignore_case" or "respect_case"
    },
  },
}

-- TODO: Check if the plugin is loaded first.
for _, ext in pairs { "fzf", "dap", "notify", "projects" } do
  telescope.load_extension(ext)
end
