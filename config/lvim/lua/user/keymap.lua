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

-- Trouble + neotest
local trouble_keys = {
  name = "+Trouble/Test",
  r = { "<cmd>Trouble lsp_references<cr>", "References" },
  q = { "<cmd>Trouble quickfix<cr>", "Quick Fix" },
  l = { "<cmd>Trouble loclist<cr>", "Location List" },
  d = { "<cmd>Trouble document_diagnostics<cr>", "Diagnostics" },
  w = { "<cmd>Trouble workspace_diagnostics<cr>", "Workspace Diagnostics" },
  t = { "<cmd>TodoTrouble<cr>", "TODO comments" },
  m = { "<cmd>lua require('neotest').run.run()<cr>", "Test Method" },
  f = { "<cmd>lua require('neotest').run.run({vim.fn.expand('%')})<cr>", "Test File" },
  s = { "<cmd>lua require('neotest').summary.toggle()<cr>", "Test Summary" },
  S = { "<cmd>lua require('neotest').output_panel.open()<cr>", "Test Summary panel" },
  o = { "<cmd>lua require('neotest').output.open()<cr>", "Output Window" }
}
lvim.builtin.which_key.mappings["t"] = trouble_keys
lvim.builtin.which_key.mappings["l"]["d"] = trouble_keys.d
lvim.builtin.which_key.mappings["l"]["w"] = trouble_keys.w

-- DAP
lvim.builtin.which_key.mappings["dM"] = {
  function()
    local ft = vim.bo.filetype
    if ft == "go" then
      require("dap-go").debug_test()
    elseif ft == "python" then
      require("dap-python").test_class()
    else
      vim.notify "Debugging a single method is not supported!"
    end
  end,
  "Debug Method" }
lvim.builtin.which_key.mappings["dF"] = {
  function()
    local ft = vim.bo.filetype
    if ft == "python" then
      require("dap-python").test_class()
    else
      vim.notify "Debugging a single class is not supported!"
    end
  end,
  "Debug Class" }
