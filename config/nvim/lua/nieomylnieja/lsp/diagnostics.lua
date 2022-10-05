-- Diagnostic icons
local signs = {
  { name = "DiagnosticSignError", text = "" },
  { name = "DiagnosticSignWarn", text = "" },
  { name = "DiagnosticSignHint", text = "" },
  { name = "DiagnosticSignInfo", text = "" },
}
for _, sign in ipairs(signs) do
  vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
end

-- Keymaps
local nmap = function(keys, func, desc)
  if desc then
    desc = "Diagnostics: " .. desc
  end
  require("nieomylnieja.keymap").nnoremap(keys, func, { silent = true, desc = desc })
end

nmap("gl", vim.diagnostic.open_float, "Open diagnostics popup")
nmap("[d", vim.diagnostic.goto_prev, "Goto previous diagnostic")
nmap("]d", vim.diagnostic.goto_next, "Goto previous diagnostic")
nmap("<space>q", vim.diagnostic.setloclist, "Set local")

local config = {
  -- disable virtual text
  virtual_lines = false,
  virtual_text = false,
  -- virtual_text = {
  --   -- spacing = 7,
  --   -- update_in_insert = false,
  --   -- severity_sort = true,
  --   -- prefix = "<-",
  --   prefix = " ●",
  --   source = "if_many", -- Or "always"
  --   -- format = function(diag)
  --   --   return diag.message .. "blah"
  --   -- end,
  -- },

  -- show signs
  signs = {
    active = signs,
  },
  update_in_insert = true,
  underline = true,
  severity_sort = true,
  float = {
    focusable = true,
    style = "minimal",
    border = "rounded",
    -- border = {"▄","▄","▄","█","▀","▀","▀","█"},
    source = "if_many", -- Or "always"
    header = "",
    prefix = "",
    -- width = 40,
  },
}

vim.diagnostic.config(config)

local is_loaded, trouble = pcall(require, "trouble")
if not is_loaded then
  return
end

trouble.setup {
  position = "bottom", -- position of the list can be: bottom, top, left, right
  height = 10, -- height of the trouble list when position is top or bottom
  width = 50, -- width of the list when position is left or right
  icons = true, -- use devicons for filenames
  mode = "workspace_diagnostics", -- "workspace_diagnostics", "document_diagnostics", "quickfix", "lsp_references", "loclist"
  fold_open = "", -- icon used for open folds
  fold_closed = "", -- icon used for closed folds
  group = true, -- group results by file
  padding = true, -- add an extra new line on top of the list
  action_keys = { -- key mappings for actions in the trouble list
    -- map to {} to remove a mapping, for example:
    -- close = {},
    close = "q", -- close the list
    cancel = "<esc>", -- cancel the preview and get back to your last window / buffer / cursor
    refresh = "r", -- manually refresh
    jump = { "<cr>", "<tab>" }, -- jump to the diagnostic or open / close folds
    open_split = { "<c-x>" }, -- open buffer in new split
    open_vsplit = { "<c-v>" }, -- open buffer in new vsplit
    open_tab = { "<c-t>" }, -- open buffer in new tab
    jump_close = { "o" }, -- jump to the diagnostic and close the list
    toggle_mode = "m", -- toggle between "workspace" and "document" diagnostics mode
    toggle_preview = "P", -- toggle auto_preview
    hover = "K", -- opens a small popup with the full multiline message
    preview = "p", -- preview the diagnostic location
    close_folds = { "zM", "zm" }, -- close all folds
    open_folds = { "zR", "zr" }, -- open all folds
    toggle_fold = { "zA", "za" }, -- toggle fold of current file
    previous = "k", -- previous item
    next = "j", -- next item
  },
  indent_lines = true, -- add an indent guide below the fold icons
  auto_open = false, -- automatically open the list when you have diagnostics
  auto_close = false, -- automatically close the list when you have no diagnostics
  auto_preview = true, -- automatically preview the location of the diagnostic. <esc> to close preview and go back to last window
  auto_fold = false, -- automatically fold a file trouble list at creation
  auto_jump = { "lsp_definitions" }, -- for the given modes, automatically jump if there is only a single result
  signs = {
    other = "﫠",
  },
  use_diagnostic_signs = true, -- enabling this will use the signs defined in your lsp client
}
