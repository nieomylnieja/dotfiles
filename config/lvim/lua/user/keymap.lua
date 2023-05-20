lvim.leader = "space"

lvim.keys.normal_mode["<C-s>"] = ":w<cr>"
lvim.keys.normal_mode["<S-l>"] = ":BufferLineCycleNext<CR>"
lvim.keys.normal_mode["<S-h>"] = ":BufferLineCyclePrev<CR>"

-- LSP
for key, func in pairs({
  ["gd"] = "<cmd>Telescope lsp_definitions<cr>",
  ["gI"] = "<cmd>Telescope lsp_implementations<cr>",
  ["gr"] = "<cmd>Telescope lsp_references<cr>",
}) do
  lvim.lsp.buffer_mappings.normal_mode[key][1] = func
end

-- Telescope
lvim.builtin.which_key.mappings["s"] = {} -- Clear the old mapping
lvim.builtin.which_key.mappings["f"] = {
  name = "Find",
  b = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
  c = { "<cmd>Telescope colorscheme<cr>", "Colorscheme" },
  f = { "<cmd>Telescope find_files<cr>", "Find file" },
  h = { "<cmd>Telescope help_tags<cr>", "Find help" },
  H = { "<cmd>Telescope highlights<cr>", "Find highlight groups" },
  M = { "<cmd>Telescope man_pages<cr>", "Man pages" },
  r = { "<cmd>Telescope oldfiles<cr>", "Open recent file" },
  R = { "<cmd>Telescope registers<cr>", "Registers" },
  g = { "<cmd>Telescope live_grep<cr>", "Live grep" },
  k = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
  C = { "<cmd>Telescope commands<cr>", "Commands" },
  l = { "<cmd>Telescope resume<cr>", "Resume last search" },
  t = { "<cmd>TodoTelescope<cr>", "TODO comments" }
}

-- Trouble
local trouble_keys = {
  name = "+Trouble",
  r = { "<cmd>Trouble lsp_references<cr>", "References" },
  f = { "<cmd>Trouble lsp_definitions<cr>", "Definitions" },
  q = { "<cmd>Trouble quickfix<cr>", "QuickFix" },
  l = { "<cmd>Trouble loclist<cr>", "LocationList" },
  d = { "<cmd>Trouble document_diagnostics<cr>", "Diagnostics" },
  w = { "<cmd>Trouble workspace_diagnostics<cr>", "Workspace Diagnostics" },
  t = { "<cmd>TodoTrouble<cr>", "TODO comments" }
}
lvim.builtin.which_key.mappings["t"] = trouble_keys
lvim.builtin.which_key.mappings["l"]["d"] = trouble_keys.d
lvim.builtin.which_key.mappings["l"]["w"] = trouble_keys.w
