local M = {}

M.setup = function()
  if not vim.g.neovide then
    return
  end

  vim.g.neovide_transparency = 0.9
  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0
  vim.g.neovide_hide_mouse_when_typing = true
  vim.g.neovide_scale_factor = 1.0

  vim.g.gui_font_default_size = 14
  vim.g.gui_font_size = vim.g.gui_font_default_size
  vim.g.gui_font_face = "mononoki Nerd Font Mono"

  local RefreshGuiFont = function()
    vim.opt.guifont = string.format("%s:h%s", vim.g.gui_font_face, vim.g.gui_font_size)
  end

  local ResizeGuiFont = function(delta)
    vim.g.gui_font_size = vim.g.gui_font_size + delta
    RefreshGuiFont()
  end

  local ResetGuiFont = function()
    vim.g.gui_font_size = vim.g.gui_font_default_size
    RefreshGuiFont()
  end

  -- Call function on startup to set default value
  ResetGuiFont()

  -- Keymaps
  local opts = { noremap = true, silent = true }
  vim.keymap.set({ "n", "i" }, "<C-=>", function()
    ResizeGuiFont(1)
  end, opts)
  vim.keymap.set({ "n", "i" }, "<C-->", function()
    ResizeGuiFont(-1)
  end, opts)
  vim.keymap.set({ "n", "i" }, "<C-BS>", function()
    ResetGuiFont()
  end, opts)
end

return M
