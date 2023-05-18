lvim.leader = "space"

lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"

local telescope = require "telescope.builtin"

-- LSP
for key, func in pairs({
  ["gd"] = telescope.lsp_definitions,
  ["gI"] = telescope.lsp_implementations,
  ["gr"] = telescope.lsp_references,
}) do
  lvim.lsp.buffer_mappings.normal_mode[key][1] = func
end

-- Telescope
lvim.builtin.which_key.mappings["s"] = {} -- Clear the old mapping
lvim.builtin.which_key.mappings["f"] = {
  name = "Find",
  b = { telescope.git_branches, "Checkout branch" },
  c = { telescope.colorscheme, "Colorscheme" },
  f = { telescope.find_files, "Find file" },
  h = { telescope.help_tags, "Find help" },
  H = { telescope.highlights, "Find highlight groups" },
  M = { telescope.man_pages, "Man pages" },
  r = { telescope.oldfiles, "Open recent file" },
  R = { telescope.registers, "Registers" },
  g = { telescope.live_grep, "Live grep" },
  k = { telescope.keymaps, "Keymaps" },
  C = { telescope.commands, "Commands" },
  l = { telescope.resume, "Resume last search" },
}

-- Trouble
lvim.builtin.which_key.mappings["t"] = {
  name = "+Trouble",
  r = { "<cmd>Trouble lsp_references<cr>", "References" },
  f = { "<cmd>Trouble lsp_definitions<cr>", "Definitions" },
  q = { "<cmd>Trouble quickfix<cr>", "QuickFix" },
  l = { "<cmd>Trouble loclist<cr>", "LocationList" },
  d = { "<cmd>Trouble document_diagnostics<cr>", "Diagnostics" },
  w = { "<cmd>Trouble workspace_diagnostics<cr>", "Workspace Diagnostics" },
}
