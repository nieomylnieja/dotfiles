local M = {}

local nord = require "user.colors.theme"

-- Go trough the table and highlight the group with the color values
M.highlight = function(group, color)
  local style = color.style and "gui=" .. color.style or "gui=NONE"
  local fg = color.fg and "guifg=" .. color.fg or "guifg=NONE"
  local bg = color.bg and "guibg=" .. color.bg or "guibg=NONE"
  local sp = color.sp and "guisp=" .. color.sp or ""

  local hl = "highlight " .. group .. " " .. style .. " " .. fg .. " " .. bg .. " " .. sp

  vim.cmd(hl)
  if color.link then
    vim.cmd("highlight! link " .. group .. " " .. color.link)
  end
end

-- Only define nord if it's the active colorscheme
function M.onColorScheme()
  if vim.g.colors_name ~= "nord" then
    vim.cmd [[autocmd! nord]]
    vim.cmd [[augroup! nord]]
  end
end

-- Change the background for the terminal, packer and qf windows
M.contrast = function()
  vim.cmd([[
    augroup nord
      autocmd!
      autocmd ColorScheme * lua require("nord.util").onColorScheme()
      autocmd TermOpen * setlocal winhighlight=Normal:NormalFloat,SignColumn:NormalFloat
      autocmd FileType packer setlocal winhighlight=Normal:NormalFloat,SignColumn:NormalFloat
      autocmd FileType qf setlocal winhighlight=Normal:NormalFloat,SignColumn:NormalFloat
    augroup end
  ]])
end
-- Loads the colors from the dictionary Object (colorSet)
function M.loadColorSet(colorSet)
  for group, colors in pairs(colorSet) do
    M.highlight(group, colors)
  end
end

-- Load the theme
function M.setup()
  -- Set the theme environment
  vim.cmd "hi clear"
  if vim.fn.exists "syntax_on" then
    vim.cmd "syntax reset"
  end
  vim.o.termguicolors = true
  vim.g.colors_name = "nord"

  local editor = nord.loadEditor()
  local syntax = nord.loadSyntax()
  local treesitter = nord.loadTreeSitter()
  local semanticTokens = nord.loadSemanitcTokens()
  local filetypes = nord.loadFiletypes()
  local plugins = nord.loadPlugins()
  local lsp = nord.loadLSP()

  -- load highlights
  M.loadColorSet(editor)
  M.loadColorSet(syntax)
  M.loadColorSet(treesitter)
  M.loadColorSet(filetypes)
  M.loadColorSet(plugins)
  M.loadColorSet(lsp)
  M.loadColorSet(semanticTokens)

  nord.loadTerminal()

  -- if contrast is enabled, apply it to sidebars and floating windows
  if vim.g.nord_contrast == true then
    M.contrast()
  end

  -- Fix priority collision for builtin and readonly mods.
  -- This makes it so that for example `const` is bold white, but `nil` is glacier.
  -- vim.api.nvim_create_autocmd("LspTokenUpdate", {
  --   callback = function(args)
  --     local token = args.data.token
  --     if not token.modifiers.readonly then
  --       return
  --     end
  --     if token.modifiers.builtin or token.modifiers.defaultLibrary then
  --       vim.lsp.semantic_tokens.highlight_token(
  --         token, args.buf, args.data.client_id, '@lsp.mod.builtin'
  --       )
  --     end
  --   end,
  -- })
end

return M
