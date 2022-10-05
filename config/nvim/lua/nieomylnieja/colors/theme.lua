local theme = {}

local nord = require "nieomylnieja.colors.nord"

theme.loadSyntax = function()
  -- Syntax highlight groups
  local syntax = {
    Type = { fg = nord.glacier }, -- int, long, char, etc.
    StorageClass = { fg = nord.glacier }, -- static, register, volatile, etc.
    Structure = { fg = nord.glacier }, -- struct, union, enum, etc.
    Constant = { fg = nord.darkest_white }, -- any constant
    Character = { fg = nord.green }, -- any character constant: 'c', '\n'
    Number = { fg = nord.purple }, -- a number constant: 5
    Boolean = { fg = nord.glacier }, -- a boolean constant: TRUE, false
    Float = { fg = nord.purple }, -- a floating point constant: 2.3e10
    Statement = { fg = nord.glacier }, -- any statement
    Label = { fg = nord.glacier }, -- case, default, etc.
    Operator = { fg = nord.glacier }, -- sizeof", "+", "*", etc.
    Exception = { fg = nord.glacier }, -- try, catch, throw
    PreProc = { fg = nord.glacier }, -- generic Preprocessor
    Include = { fg = nord.glacier }, -- preprocessor #include
    Define = { fg = nord.glacier }, -- preprocessor #define
    Macro = { fg = nord.glacier }, -- same as Define
    Typedef = { fg = nord.glacier }, -- A typedef
    PreCondit = { fg = nord.yellow }, -- preprocessor #if, #else, #endif, etc.
    Special = { fg = nord.darkest_white }, -- any special symbol
    SpecialChar = { fg = nord.yellow }, -- special character in a constant
    Tag = { fg = nord.darkest_white }, -- you can use CTRL-] on this
    Delimiter = { fg = nord.white }, -- character that needs attention like , or .
    SpecialComment = { fg = nord.off_blue }, -- special things inside a comment
    Debug = { fg = nord.red }, -- debugging statements
    Underlined = { fg = nord.green, bg = nord.none, style = "underline" }, -- text that stands out, HTML links
    Ignore = { fg = nord.dark_gray }, -- left blank, hidden
    Error = { fg = nord.red, bg = nord.none, style = "bold,underline" }, -- any erroneous construct
    Todo = { fg = nord.yellow, bg = nord.none, style = "bold,italic" }, -- anything that needs extra attention; mostly the keywords TODO FIXME and XXX
    Conceal = { fg = nord.none, bg = nord.black },

    htmlLink = { fg = nord.green, style = "underline" },
    htmlH1 = { fg = nord.off_blue, style = "bold" },
    htmlH2 = { fg = nord.red, style = "bold" },
    htmlH3 = { fg = nord.green, style = "bold" },
    htmlH4 = { fg = nord.purple, style = "bold" },
    htmlH5 = { fg = nord.glacier, style = "bold" },
    markdownH1 = { fg = nord.off_blue, style = "bold" },
    markdownH2 = { fg = nord.red, style = "bold" },
    markdownH3 = { fg = nord.green, style = "bold" },
    markdownH1Delimiter = { fg = nord.off_blue },
    markdownH2Delimiter = { fg = nord.red },
    markdownH3Delimiter = { fg = nord.green },
  }

  -- Italic comments
  if vim.g.nord_italic == false then
    syntax.Comment = { fg = nord.light_gray_bright } -- normal comments
    syntax.Conditional = { fg = nord.glacier } -- normal if, then, else, endif, switch, etc.
    syntax.Function = { fg = nord.off_blue } -- normal function names
    syntax.Identifier = { fg = nord.glacier } -- any variable name
    syntax.Keyword = { fg = nord.glacier } -- normal for, do, while, etc.
    syntax.Repeat = { fg = nord.glacier } -- normal any other keyword
    syntax.String = { fg = nord.green } -- any string
  else
    syntax.Comment = { fg = nord.light_gray_bright, bg = nord.none, style = "italic" } -- italic comments
    syntax.Conditional = { fg = nord.glacier, bg = nord.none, style = "italic" } -- italic if, then, else, endif, switch, etc.
    syntax.Function = { fg = nord.off_blue, bg = nord.none, style = "italic" } -- italic funtion names
    syntax.Identifier = { fg = nord.glacier, bg = nord.none, style = "italic" } -- any variable name
    syntax.Keyword = { fg = nord.glacier, bg = nord.none, style = "italic" } -- italic for, do, while, etc.
    syntax.Repeat = { fg = nord.glacier, bg = nord.none, style = "italic" } -- italic any other keyword
    syntax.String = { fg = nord.green, bg = nord.none, style = "italic" } -- any string
  end

  return syntax
end

theme.loadEditor = function()
  -- Editor highlight groups

  local editor = {
    NormalFloat = { fg = nord.darkest_white, bg = nord.float }, -- normal text and background color
    FloatBorder = { fg = nord.darkest_white, bg = nord.float }, -- normal text and background color
    ColorColumn = { fg = nord.none, bg = nord.dark_gray }, --  used for the columns set with 'colorcolumn'
    Conceal = { fg = nord.dark_gray }, -- placeholder characters substituted for concealed text (see 'conceallevel')
    Cursor = { fg = nord.darkest_white, bg = nord.none, style = "reverse" }, -- the character under the cursor
    CursorIM = { fg = nord.darker_white, bg = nord.none, style = "reverse" }, -- like Cursor, but used when in IME mode
    Directory = { fg = nord.teal, bg = nord.none }, -- directory names (and other special names in listings)
    EndOfBuffer = { fg = nord.dark_gray },
    ErrorMsg = { fg = nord.none },
    Folded = { fg = nord.light_gray_bright, bg = nord.none, style = "italic" },
    FoldColumn = { fg = nord.teal },
    IncSearch = { fg = nord.white, bg = nord.blue },
    LineNr = { fg = nord.light_gray_bright },
    CursorLineNr = { fg = nord.darkest_white },
    MatchParen = { fg = nord.purple, bg = nord.none, style = "bold" },
    ModeMsg = { fg = nord.darkest_white },
    MoreMsg = { fg = nord.darkest_white },
    NonText = { fg = nord.dark_gray },
    Pmenu = { fg = nord.darkest_white, bg = nord.gray },
    PmenuSel = { fg = nord.darkest_white, bg = nord.blue },
    PmenuSbar = { fg = nord.darkest_white, bg = nord.gray },
    PmenuThumb = { fg = nord.darkest_white, bg = nord.darkest_white },
    Question = { fg = nord.green },
    QuickFixLine = { fg = nord.darkest_white, bg = nord.none, style = "reverse" },
    qfLineNr = { fg = nord.darkest_white, bg = nord.none, style = "reverse" },
    Search = { fg = nord.blue, bg = nord.white, style = "reverse" },
    SpecialKey = { fg = nord.glacier },
    SpellBad = { fg = nord.red, bg = nord.none, style = "italic,undercurl" },
    SpellCap = { fg = nord.teal, bg = nord.none, style = "italic,undercurl" },
    SpellLocal = { fg = nord.off_blue, bg = nord.none, style = "italic,undercurl" },
    SpellRare = { fg = nord.glacier, bg = nord.none, style = "italic,undercurl" },
    StatusLine = { fg = nord.darkest_white, bg = nord.gray },
    StatusLineNC = { fg = nord.darkest_white, bg = nord.dark_gray },
    StatusLineTerm = { fg = nord.darkest_white, bg = nord.gray },
    StatusLineTermNC = { fg = nord.darkest_white, bg = nord.dark_gray },
    TabLineFill = { fg = nord.darkest_white, bg = nord.none },
    TablineSel = { fg = nord.dark_gray, bg = nord.glacier },
    Tabline = { fg = nord.darkest_white, bg = nord.dark_gray },
    Title = { fg = nord.green, bg = nord.none, style = "bold" },
    Visual = { fg = nord.none, bg = nord.gray },
    VisualNOS = { fg = nord.none, bg = nord.gray },
    WarningMsg = { fg = nord.purple },
    WildMenu = { fg = nord.orange, bg = nord.none, style = "bold" },
    CursorColumn = { fg = nord.none, bg = nord.cursorlinefg },
    CursorLine = { fg = nord.none, bg = nord.cursorlinefg },
    ToolbarLine = { fg = nord.darkest_white, bg = nord.dark_gray },
    ToolbarButton = { fg = nord.darkest_white, bg = nord.none, style = "bold" },
    NormalMode = { fg = nord.darkest_white, bg = nord.none, style = "reverse" },
    InsertMode = { fg = nord.green, bg = nord.none, style = "reverse" },
    ReplacelMode = { fg = nord.red, bg = nord.none, style = "reverse" },
    VisualMode = { fg = nord.glacier, bg = nord.none, style = "reverse" },
    CommandMode = { fg = nord.darkest_white, bg = nord.none, style = "reverse" },
    Warnings = { fg = nord.purple },

    healthError = { fg = nord.red },
    healthSuccess = { fg = nord.green },
    healthWarning = { fg = nord.purple },

    -- dashboard
    DashboardShortCut = { fg = nord.teal },
    DashboardHeader = { fg = nord.glacier },
    DashboardCenter = { fg = nord.off_blue },
    DashboardFooter = { fg = nord.green, style = "italic" },

    -- Barbar
    BufferTabpageFill = { bg = nord.black },

    BufferCurrent = { bg = nord.dark_gray },
    BufferCurrentMod = { bg = nord.dark_gray, fg = nord.purple },
    BufferCurrentIcon = { bg = nord.dark_gray },
    BufferCurrentSign = { bg = nord.dark_gray },
    BufferCurrentIndex = { bg = nord.dark_gray },
    BufferCurrentTarget = { bg = nord.dark_gray, fg = nord.red },

    BufferInactive = { bg = nord.black, fg = nord.light_gray },
    BufferInactiveMod = { bg = nord.black, fg = nord.purple },
    BufferInactiveIcon = { bg = nord.black, fg = nord.light_gray },
    BufferInactiveSign = { bg = nord.black, fg = nord.light_gray },
    BufferInactiveIndex = { bg = nord.black, fg = nord.light_gray },
    BufferInactiveTarget = { bg = nord.black, fg = nord.red },

    BufferVisible = { bg = nord.gray },
    BufferVisibleMod = { bg = nord.gray, fg = nord.purple },
    BufferVisibleIcon = { bg = nord.gray },
    BufferVisibleSign = { bg = nord.gray },
    BufferVisibleIndex = { bg = nord.gray },
    BufferVisibleTarget = { bg = nord.gray, fg = nord.red },

    -- nvim-notify
    NotifyDEBUGBorder = { fg = nord.light_gray },
    NotifyDEBUGIcon = { fg = nord.light_gray },
    NotifyDEBUGTitle = { fg = nord.light_gray },
    NotifyERRORBorder = { fg = nord.red },
    NotifyERRORIcon = { fg = nord.red },
    NotifyERRORTitle = { fg = nord.red },
    NotifyINFOBorder = { fg = nord.green },
    NotifyINFOIcon = { fg = nord.green },
    NotifyINFOTitle = { fg = nord.green },
    NotifyTRACEBorder = { fg = nord.purple },
    NotifyTRACEIcon = { fg = nord.purple },
    NotifyTRACETitle = { fg = nord.purple },
    NotifyWARNBorder = { fg = nord.yellow },
    NotifyWARNIcon = { fg = nord.yellow },
    NotifyWARNTitle = { fg = nord.yellow },

    -- leap.nvim
    LeapMatch = { style = "underline,nocombine", fg = nord.yellow },
    LeapLabelPrimary = { style = "nocombine", fg = nord.black, bg = nord.yellow },
    LeapLabelSecondary = { style = "nocombine", fg = nord.black, bg = nord.purple },
  }

  -- Options:

  --Set transparent background
  if vim.g.nord_disable_background then
    editor.Normal = { fg = nord.darkest_white, bg = nord.none } -- normal text and background color
    editor.SignColumn = { fg = nord.darkest_white, bg = nord.none }
  else
    editor.Normal = { fg = nord.darkest_white, bg = nord.black } -- normal text and background color
    editor.SignColumn = { fg = nord.darkest_white, bg = nord.black }
  end

  -- Remove window split borders
  if vim.g.nord_borders then
    editor.VertSplit = { fg = nord.gray }
  else
    editor.VertSplit = { fg = nord.black }
  end

  if vim.g.nord_uniform_diff_background then
    editor.DiffAdd = { fg = nord.green, bg = nord.dark_gray } -- diff mode: Added line
    editor.DiffChange = { fg = nord.yellow, bg = nord.dark_gray } --  diff mode: Changed line
    editor.DiffDelete = { fg = nord.red, bg = nord.dark_gray } -- diff mode: Deleted line
    editor.DiffText = { fg = nord.purple, bg = nord.dark_gray } -- diff mode: Changed text within a changed line
  else
    editor.DiffAdd = { fg = nord.green, bg = nord.none, style = "reverse" } -- diff mode: Added line
    editor.DiffChange = { fg = nord.yellow, bg = nord.none, style = "reverse" } --  diff mode: Changed line
    editor.DiffDelete = { fg = nord.red, bg = nord.none, style = "reverse" } -- diff mode: Deleted line
    editor.DiffText = { fg = nord.purple, bg = nord.none, style = "reverse" } -- diff mode: Changed text within a changed line
  end

  return editor
end

theme.loadTerminal = function()
  vim.g.terminal_color_0 = nord.dark_gray
  vim.g.terminal_color_1 = nord.red
  vim.g.terminal_color_2 = nord.green
  vim.g.terminal_color_3 = nord.yellow
  vim.g.terminal_color_4 = nord.glacier
  vim.g.terminal_color_5 = nord.purple
  vim.g.terminal_color_6 = nord.off_blue
  vim.g.terminal_color_7 = nord.darker_white
  vim.g.terminal_color_8 = nord.light_gray
  vim.g.terminal_color_9 = nord.red
  vim.g.terminal_color_10 = nord.green
  vim.g.terminal_color_11 = nord.yellow
  vim.g.terminal_color_12 = nord.glacier
  vim.g.terminal_color_13 = nord.purple
  vim.g.terminal_color_14 = nord.teal
  vim.g.terminal_color_15 = nord.white
end

theme.loadTreeSitter = function()
  -- TreeSitter highlight groups

  local treesitter = {
    TSAnnotation = { fg = nord.orange }, -- For C++/Dart attributes, annotations thatcan be attached to the code to denote some kind of meta information.
    TSConstructor = { fg = nord.glacier }, -- For constructor calls and definitions: `= { }` in Lua, and Java constructors.
    TSConstant = { fg = nord.darkest_white, style = "bold" }, -- For constants
    TSFloat = { fg = nord.purple }, -- For floats
    TSNumber = { fg = nord.purple }, -- For all number
    TSAttribute = { fg = nord.purple }, -- (unstable) TODO: docs
    TSVariable = { fg = nord.darkest_white }, -- Any variable name that does not have another highlight.
    TSVariableBuiltin = { fg = nord.darkest_white, style = "bold" },
    TSBoolean = { fg = nord.glacier }, -- For booleans.
    TSConstBuiltin = { fg = nord.glacier }, -- For constant that are built in the language: `nil` in Lua.
    TSConstMacro = { fg = nord.teal, style = "bold" }, -- For constants that are defined by macros: `NULL` in C.
    TSError = { fg = nord.red }, -- For syntax/parser errors.
    TSException = { fg = nord.purple }, -- For exception related keywords.
    TSFuncMacro = { fg = nord.teal }, -- For macro defined fuctions (calls and definitions): each `macro_rules` in Rust.
    TSInclude = { fg = nord.glacier }, -- For includes: `#include` in C, `use` or `extern crate` in Rust, or `require` in Lua.
    TSLabel = { fg = nord.purple }, -- For labels: `label:` in C and `:label:` in Lua.
    TSOperator = { fg = nord.glacier }, -- For any operator: `+`, but also `->` and `*` in C.
    TSParameter = { fg = nord.darkest_white }, -- For parameters of a function.
    TSParameterReference = { fg = nord.darkest_white }, -- For references to parameters of a function.
    TSPunctDelimiter = { fg = nord.white }, -- For delimiters ie: `.`
    TSPunctBracket = { fg = nord.white }, -- For brackets and parens.
    TSPunctSpecial = { fg = nord.white }, -- For special punctutation that does not fall in the catagories before.
    TSSymbol = { fg = nord.purple }, -- For identifiers referring to symbols or atoms.
    TSType = { fg = nord.teal }, -- For types.
    TSTypeBuiltin = { fg = nord.glacier }, -- For builtin types.
    TSTag = { fg = nord.darkest_white }, -- Tags like html tag names.
    TSTagDelimiter = { fg = nord.purple }, -- Tag delimiter like `<` `>` `/`
    TSText = { fg = nord.darkest_white }, -- For strings considered text in a markup language.
    TSTextReference = { fg = nord.purple }, -- FIXME
    TSEmphasis = { fg = nord.blue }, -- For text to be represented with emphasis.
    TSUnderline = { fg = nord.darkest_white, bg = nord.none, style = "underline" }, -- For text to be represented with an underline.
    TSTitle = { fg = nord.blue, bg = nord.none, style = "bold" }, -- Text that is part of a title.
    TSLiteral = { fg = nord.darkest_white }, -- Literal text.
    TSURI = { fg = nord.green }, -- Any URI like a link or email.
  }

  local italics_candidates = {
    TSComment = { fg = nord.light_gray_bright },
    TSConditional = { fg = nord.glacier }, -- For keywords related to conditionnals.
    TSFunction = { fg = nord.off_blue }, -- For fuction (calls and definitions).
    TSMethod = { fg = nord.off_blue }, -- For method calls and definitions.
    TSFuncBuiltin = { fg = nord.off_blue },
    TSNamespace = { fg = nord.darkest_white }, -- For identifiers referring to modules and namespaces.
    TSField = { fg = nord.darkest_white }, -- For fields in literals
    TSProperty = { fg = nord.darkest_white }, -- Same as `TSField`
    TSKeyword = { fg = nord.glacier }, -- For keywords that don't fall in other categories.
    TSKeywordFunction = { fg = nord.glacier },
    TSKeywordReturn = { fg = nord.glacier },
    TSKeywordOperator = { fg = nord.glacier },
    TSRepeat = { fg = nord.glacier }, -- For keywords related to loops.
    TSString = { fg = nord.green }, -- For strings.
    TSStringRegex = { fg = nord.teal }, -- For regexes.
    TSStringEscape = { fg = nord.purple }, -- For escape characters within a string.
    TSCharacter = { fg = nord.green }, -- For characters.
  }

  for k, v in pairs(italics_candidates) do
    if vim.g.nord_italic == true then
      v.style = "italic"
    end
    treesitter[k] = v
  end

  return treesitter
end

theme.loadFiletypes = function()
  -- Filetype-specific highlight groups

  local ft = {
    -- yaml
    yamlBlockMappingKey = { fg = nord.teal },
    yamlBool = { link = "Boolean" },
    yamlDocumentStart = { link = "Keyword" },
    yamlTSField = { fg = nord.teal },
    yamlTSString = { fg = nord.darkest_white },
    yamlTSPunctSpecial = { link = "Keyword" },
    yamlKey = { fg = nord.teal }, -- stephpy/vim-yaml
  }

  return ft
end

theme.loadLSP = function()
  -- Lsp highlight groups

  local lsp = {
    LspDiagnosticsDefaultError = { fg = nord.red }, -- used for "Error" diagnostic virtual text
    LspDiagnosticsSignError = { fg = nord.red }, -- used for "Error" diagnostic signs in sign column
    LspDiagnosticsFloatingError = { fg = nord.red }, -- used for "Error" diagnostic messages in the diagnostics float
    LspDiagnosticsVirtualTextError = { fg = nord.red }, -- Virtual text "Error"
    LspDiagnosticsUnderlineError = { style = "undercurl", sp = nord.red }, -- used to underline "Error" diagnostics.
    LspDiagnosticsDefaultWarning = { fg = nord.purple }, -- used for "Warning" diagnostic signs in sign column
    LspDiagnosticsSignWarning = { fg = nord.purple }, -- used for "Warning" diagnostic signs in sign column
    LspDiagnosticsFloatingWarning = { fg = nord.purple }, -- used for "Warning" diagnostic messages in the diagnostics float
    LspDiagnosticsVirtualTextWarning = { fg = nord.purple }, -- Virtual text "Warning"
    LspDiagnosticsUnderlineWarning = { style = "undercurl", sp = nord.purple }, -- used to underline "Warning" diagnostics.
    LspDiagnosticsDefaultInformation = { fg = nord.blue }, -- used for "Information" diagnostic virtual text
    LspDiagnosticsSignInformation = { fg = nord.blue }, -- used for "Information" diagnostic signs in sign column
    LspDiagnosticsFloatingInformation = { fg = nord.blue }, -- used for "Information" diagnostic messages in the diagnostics float
    LspDiagnosticsVirtualTextInformation = { fg = nord.blue }, -- Virtual text "Information"
    LspDiagnosticsUnderlineInformation = { style = "undercurl", sp = nord.blue }, -- used to underline "Information" diagnostics.
    LspDiagnosticsDefaultHint = { fg = nord.glacier }, -- used for "Hint" diagnostic virtual text
    LspDiagnosticsSignHint = { fg = nord.glacier }, -- used for "Hint" diagnostic signs in sign column
    LspDiagnosticsFloatingHint = { fg = nord.glacier }, -- used for "Hint" diagnostic messages in the diagnostics float
    LspDiagnosticsVirtualTextHint = { fg = nord.glacier }, -- Virtual text "Hint"
    LspDiagnosticsUnderlineHint = { style = "undercurl", sp = nord.blue }, -- used to underline "Hint" diagnostics.
    LspReferenceText = { fg = nord.darkest_white, bg = nord.dark_gray }, -- used for highlighting "text" references
    LspReferenceRead = { fg = nord.darkest_white, bg = nord.dark_gray }, -- used for highlighting "read" references
    LspReferenceWrite = { fg = nord.darkest_white, bg = nord.dark_gray }, -- used for highlighting "write" references

    DiagnosticError = { link = "LspDiagnosticsDefaultError" },
    DiagnosticWarn = { link = "LspDiagnosticsDefaultWarning" },
    DiagnosticInfo = { link = "LspDiagnosticsDefaultInformation" },
    DiagnosticHint = { link = "LspDiagnosticsDefaultHint" },
    DiagnosticVirtualTextWarn = { link = "LspDiagnosticsVirtualTextWarning" },
    DiagnosticUnderlineWarn = { link = "LspDiagnosticsUnderlineWarning" },
    DiagnosticFloatingWarn = { link = "LspDiagnosticsFloatingWarning" },
    DiagnosticSignWarn = { link = "LspDiagnosticsSignWarning" },
    DiagnosticVirtualTextError = { link = "LspDiagnosticsVirtualTextError" },
    DiagnosticUnderlineError = { link = "LspDiagnosticsUnderlineError" },
    DiagnosticFloatingError = { link = "LspDiagnosticsFloatingError" },
    DiagnosticSignError = { link = "LspDiagnosticsSignError" },
    DiagnosticVirtualTextInfo = { link = "LspDiagnosticsVirtualTextInformation" },
    DiagnosticUnderlineInfo = { link = "LspDiagnosticsUnderlineInformation" },
    DiagnosticFloatingInfo = { link = "LspDiagnosticsFloatingInformation" },
    DiagnosticSignInfo = { link = "LspDiagnosticsSignInformation" },
    DiagnosticVirtualTextHint = { link = "LspDiagnosticsVirtualTextHint" },
    DiagnosticUnderlineHint = { link = "LspDiagnosticsUnderlineHint" },
    DiagnosticFloatingHint = { link = "LspDiagnosticsFloatingHint" },
    DiagnosticSignHint = { link = "LspDiagnosticsSignHint" },
  }

  return lsp
end

theme.loadPlugins = function()
  -- Plugins highlight groups

  local plugins = {

    -- LspTrouble
    LspTroubleText = { fg = nord.darkest_white },
    LspTroubleCount = { fg = nord.glacier, bg = nord.blue },
    LspTroubleNormal = { fg = nord.darkest_white, bg = nord.sidebar },

    -- Diff
    diffAdded = { fg = nord.green },
    diffRemoved = { fg = nord.red },
    diffChanged = { fg = nord.purple },
    diffOldFile = { fg = nord.yelow },
    diffNewFile = { fg = nord.orange },
    diffFile = { fg = nord.teal },
    diffLine = { fg = nord.light_gray },
    diffIndexLine = { fg = nord.glacier },

    -- Neogit
    NeogitBranch = { fg = nord.blue },
    NeogitRemote = { fg = nord.glacier },
    NeogitHunkHeader = { fg = nord.off_blue },
    NeogitHunkHeaderHighlight = { fg = nord.off_blue, bg = nord.dark_gray },
    NeogitDiffContextHighlight = { bg = nord.dark_gray },
    NeogitDiffDeleteHighlight = { fg = nord.red, style = "reverse" },
    NeogitDiffAddHighlight = { fg = nord.green, style = "reverse" },

    -- GitGutter
    GitGutterAdd = { fg = nord.green }, -- diff mode: Added line |diff.txt|
    GitGutterChange = { fg = nord.purple }, -- diff mode: Changed line |diff.txt|
    GitGutterDelete = { fg = nord.red }, -- diff mode: Deleted line |diff.txt|

    -- GitSigns
    GitSignsAdd = { fg = nord.green }, -- diff mode: Added line |diff.txt|
    GitSignsAddNr = { fg = nord.green }, -- diff mode: Added line |diff.txt|
    GitSignsAddLn = { fg = nord.green }, -- diff mode: Added line |diff.txt|
    GitSignsChange = { fg = nord.purple }, -- diff mode: Changed line |diff.txt|
    GitSignsChangeNr = { fg = nord.purple }, -- diff mode: Changed line |diff.txt|
    GitSignsChangeLn = { fg = nord.purple }, -- diff mode: Changed line |diff.txt|
    GitSignsDelete = { fg = nord.red }, -- diff mode: Deleted line |diff.txt|
    GitSignsDeleteNr = { fg = nord.red }, -- diff mode: Deleted line |diff.txt|
    GitSignsDeleteLn = { fg = nord.red }, -- diff mode: Deleted line |diff.txt|
    GitSignsCurrentLineBlame = { fg = nord.light_gray_bright, style = "bold" },

    -- Telescope
    TelescopePromptBorder = { fg = nord.off_blue },
    TelescopeResultsBorder = { fg = nord.glacier },
    TelescopePreviewBorder = { fg = nord.green },
    TelescopeSelectionCaret = { fg = nord.glacier },
    TelescopeSelection = { fg = nord.glacier },
    TelescopeMatching = { fg = nord.off_blue },

    -- Neotree
    NeoTreeTabInactive = { fg = nord.light_gray, bg = nord.dark_gray },
    NeoTreeTabActive = { fg = nord.teal, bg = nord.gray },

    -- NvimTree
    NvimTreeRootFolder = { fg = nord.teal, style = "bold" },
    NvimTreeGitDirty = { fg = nord.purple },
    NvimTreeGitNew = { fg = nord.green },
    NvimTreeImageFile = { fg = nord.purple },
    NvimTreeExecFile = { fg = nord.green },
    NvimTreeSpecialFile = { fg = nord.glacier, style = "underline" },
    NvimTreeFolderName = { fg = nord.blue },
    NvimTreeEmptyFolderName = { fg = nord.dark_gray },
    NvimTreeFolderIcon = { fg = nord.darkest_white },
    NvimTreeIndentMarker = { fg = nord.dark_gray },
    LspDiagnosticsError = { fg = nord.red },
    LspDiagnosticsWarning = { fg = nord.purple },
    LspDiagnosticsInformation = { fg = nord.blue },
    LspDiagnosticsHint = { fg = nord.glacier },

    -- WhichKey
    WhichKey = { fg = nord.darkest_white, style = "bold" },
    WhichKeyGroup = { fg = nord.darkest_white },
    WhichKeyDesc = { fg = nord.teal, style = "italic" },
    WhichKeySeperator = { fg = nord.darkest_white },
    WhichKeyFloating = { bg = nord.float },
    WhichKeyFloat = { bg = nord.float },

    -- LspSaga
    DiagnosticError = { fg = nord.red },
    DiagnosticWarning = { fg = nord.purple },
    DiagnosticInformation = { fg = nord.blue },
    DiagnosticHint = { fg = nord.glacier },
    DiagnosticTruncateLine = { fg = nord.darkest_white },
    LspFloatWinNormal = { bg = nord.gray },
    LspFloatWinBorder = { fg = nord.glacier },
    LspSagaBorderTitle = { fg = nord.off_blue },
    LspSagaHoverBorder = { fg = nord.blue },
    LspSagaRenameBorder = { fg = nord.green },
    LspSagaDefPreviewBorder = { fg = nord.green },
    LspSagaCodeActionBorder = { fg = nord.teal },
    LspSagaFinderSelection = { fg = nord.green },
    LspSagaCodeActionTitle = { fg = nord.blue },
    LspSagaCodeActionContent = { fg = nord.glacier },
    LspSagaSignatureHelpBorder = { fg = nord.yellow },
    ReferencesCount = { fg = nord.glacier },
    DefinitionCount = { fg = nord.glacier },
    DefinitionIcon = { fg = nord.teal },
    ReferencesIcon = { fg = nord.teal },
    TargetWord = { fg = nord.off_blue },

    -- Sneak
    Sneak = { fg = nord.black, bg = nord.darkest_white },
    SneakScope = { bg = nord.dark_gray },

    -- Cmp
    CmpItemKind = { fg = nord.purple },
    CmpItemAbbrMatch = { fg = nord.darker_white, style = "bold" },
    CmpItemAbbrMatchFuzzy = { fg = nord.darker_white, style = "bold" },
    CmpItemAbbr = { fg = nord.darkest_white },
    CmpItemMenu = { fg = nord.green },

    -- Indent Blankline
    IndentBlanklineChar = { fg = nord.light_gray },
    IndentBlanklineContextChar = { fg = nord.blue },

    -- Illuminate
    illuminatedWord = { bg = nord.light_gray },
    illuminatedCurWord = { bg = nord.light_gray },

    -- nvim-dap
    DapBreakpoint = { fg = nord.green },
    DapStopped = { fg = nord.purple },

    -- nvim-dap-ui
    DapUIVariable = { fg = nord.darkest_white },
    DapUIScope = { fg = nord.off_blue },
    DapUIType = { fg = nord.glacier },
    DapUIValue = { fg = nord.darkest_white },
    DapUIModifiedValue = { fg = nord.off_blue },
    DapUIDecoration = { fg = nord.off_blue },
    DapUIThread = { fg = nord.off_blue },
    DapUIStoppedThread = { fg = nord.off_blue },
    DapUIFrameName = { fg = nord.darkest_white },
    DapUISource = { fg = nord.glacier },
    DapUILineNumber = { fg = nord.off_blue },
    DapUIFloatBorder = { fg = nord.off_blue },
    DapUIWatchesEmpty = { fg = nord.red },
    DapUIWatchesValue = { fg = nord.off_blue },
    DapUIWatchesError = { fg = nord.red },
    DapUIBreakpointsPath = { fg = nord.off_blue },
    DapUIBreakpointsInfo = { fg = nord.off_blue },
    DapUIBreakpointsCurrentLine = { fg = nord.off_blue },
    DapUIBreakpointsLine = { fg = nord.off_blue },

    -- Hop
    HopNextKey = { fg = nord.darkest_white, style = "bold" },
    HopNextKey1 = { fg = nord.off_blue, style = "bold" },
    HopNextKey2 = { fg = nord.darkest_white },
    HopUnmatched = { fg = nord.light_gray },

    -- Fern
    FernBranchText = { fg = nord.light_gray_bright },

    -- nvim-ts-rainbow
    rainbowcol1 = { fg = nord.purple },
    rainbowcol2 = { fg = nord.yellow },
    rainbowcol3 = { fg = nord.red },
    rainbowcol4 = { fg = nord.teal },
    rainbowcol5 = { fg = nord.off_blue },
    rainbowcol6 = { fg = nord.purple },
    rainbowcol7 = { fg = nord.yellow },

    -- lightspeed
    LightspeedLabel = { fg = nord.off_blue, style = "bold" },
    LightspeedLabelOverlapped = { fg = nord.off_blue, style = "bold,underline" },
    LightspeedLabelDistant = { fg = nord.purple, style = "bold" },
    LightspeedLabelDistantOverlapped = { fg = nord.purple, style = "bold,underline" },
    LightspeedShortcut = { fg = nord.blue, style = "bold" },
    LightspeedShortcutOverlapped = { fg = nord.blue, style = "bold,underline" },
    LightspeedMaskedChar = { fg = nord.darkest_white, bg = nord.gray, style = "bold" },
    LightspeedGreyWash = { fg = nord.light_gray_bright },
    LightspeedUnlabeledMatch = { fg = nord.darkest_white, bg = nord.dark_gray },
    LightspeedOneCharMatch = { fg = nord.off_blue, style = "bold,reverse" },
    LightspeedUniqueChar = { style = "bold,underline" },

    -- copilot
    CopilotLabel = { fg = nord.light_gray, bg = nord.none },

    -- Statusline
    StatusLineDull = { fg = nord.light_gray, bg = nord.dark_gray },
    StatusLineAccent = { fg = nord.black, bg = nord.yellow },

    -- mini.nvim
    MiniCompletionActiveParameter = { style = "underline" },

    MiniCursorword = { bg = nord.light_gray },
    MiniCursorwordCurrent = { bg = nord.light_gray },

    MiniIndentscopeSymbol = { fg = nord.blue },
    MiniIndentscopePrefix = { style = "nocombine" }, -- Make it invisible

    MiniJump = { fg = nord.black, bg = nord.darkest_white },

    MiniJump2dSpot = { fg = nord.orange, style = "bold,nocombine" },

    MiniStarterCurrent = { style = "nocombine" },
    MiniStarterFooter = { fg = nord.green, style = "italic" },
    MiniStarterHeader = { fg = nord.glacier },
    MiniStarterInactive = { link = "Comment" },
    MiniStarterItem = { link = "Normal" },
    MiniStarterItemBullet = { fg = nord.darkest_white },
    MiniStarterItemPrefix = { fg = nord.purple },
    MiniStarterSection = { fg = nord.darkest_white },
    MiniStarterQuery = { fg = nord.blue },

    MiniStatuslineDevinfo = { fg = nord.darkest_white, bg = nord.gray },
    MiniStatuslineFileinfo = { fg = nord.darkest_white, bg = nord.gray },
    MiniStatuslineFilename = { fg = nord.darkest_white, bg = nord.dark_gray },
    MiniStatuslineInactive = { fg = nord.darkest_white, bg = nord.black, style = "bold" },
    MiniStatuslineModeCommand = { fg = nord.black, bg = nord.purple, style = "bold" },
    MiniStatuslineModeInsert = { fg = nord.dark_gray, bg = nord.darkest_white, style = "bold" },
    MiniStatuslineModeNormal = { fg = nord.dark_gray, bg = nord.glacier, style = "bold" },
    MiniStatuslineModeOther = { fg = nord.black, bg = nord.yellow, style = "bold" },
    MiniStatuslineModeReplace = { fg = nord.black, bg = nord.red, style = "bold" },
    MiniStatuslineModeVisual = { fg = nord.black, bg = nord.teal, style = "bold" },

    MiniSurround = { link = "IncSearch" },

    MiniTablineCurrent = { bg = nord.dark_gray },
    MiniTablineFill = { link = "TabLineFill" },
    MiniTablineHidden = { bg = nord.black, fg = nord.light_gray },
    MiniTablineModifiedCurrent = { bg = nord.dark_gray, fg = nord.purple },
    MiniTablineModifiedHidden = { bg = nord.black, fg = nord.purple },
    MiniTablineModifiedVisible = { bg = nord.gray, fg = nord.purple },
    MiniTablineTabpagesection = { fg = nord.blue, bg = nord.white, style = "reverse,bold" },
    MiniTablineVisible = { bg = nord.gray },

    MiniTestEmphasis = { style = "bold" },
    MiniTestFail = { fg = nord.red, style = "bold" },
    MiniTestPass = { fg = nord.green, style = "bold" },

    MiniTrailspace = { bg = nord.red },

    -- Aerail
    AerialLine = { bg = nord.gray },
    AerialLineNC = { bg = nord.gray },

    AerialArrayIcon = { fg = nord.yellow },
    AerialBooleanIcon = { fg = nord.glacier, style = "bold" },
    AerialClassIcon = { fg = nord.glacier },
    AerialConstansIcon = { fg = nord.yellow },
    AerialConstructorIcon = { fg = nord.glacier },
    AerialEnumIcon = { fg = nord.glacier },
    AerialEnumMemberIcon = { fg = nord.darkest_white },
    AerialEventIcon = { fg = nord.glacier },
    AerialFieldIcon = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" }
      or { fg = nord.darkest_white },
    AerialFileIcon = { fg = nord.green },
    AerialFunctionIcon = vim.g.nord_italic and { fg = nord.off_blue, style = "italic" } or { fg = nord.off_blue },
    AerialInterfaceIcon = { fg = nord.glacier },
    AerialKeyIcon = { fg = nord.glacier },
    AerialMethodIcon = vim.g.nord_italic and { fg = nord.teal, style = "italic" } or { fg = nord.teal },
    AerialModuleIcon = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" }
      or { fg = nord.darkest_white },
    AerialNamespaceIcon = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" }
      or { fg = nord.darkest_white },
    AerialNullIcon = { fg = nord.glacier },
    AerialNumberIcon = { fg = nord.purple },
    AerialObjectIcon = { fg = nord.glacier },
    AerialOperatorIcon = { fg = nord.glacier },
    AerialPackageIcon = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" }
      or { fg = nord.darkest_white },
    AerialPropertyIcon = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" } or { fg = nord.blue },
    AerialStringIcon = vim.g.nord_italic and { fg = nord.green, style = "italic" } or { fg = nord.green },
    AerialStructIcon = { fg = nord.glacier },
    AerialTypeParameterIcon = { fg = nord.blue },
    AerialVariableIcon = { fg = nord.darkest_white, style = "bold" },

    AerialArray = { fg = nord.yellow },
    AerialBoolean = { fg = nord.glacier, style = "bold" },
    AerialClass = { fg = nord.glacier },
    AerialConstans = { fg = nord.yellow },
    AerialConstructor = { fg = nord.glacier },
    AerialEnum = { fg = nord.glacier },
    AerialEnumMember = { fg = nord.darkest_white },
    AerialEvent = { fg = nord.glacier },
    AerialField = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" } or { fg = nord.darkest_white },
    AerialFile = { fg = nord.green },
    AerialFunction = vim.g.nord_italic and { fg = nord.off_blue, style = "italic" } or { fg = nord.off_blue },
    AerialInterface = { fg = nord.glacier },
    AerialKey = { fg = nord.glacier },
    AerialMethod = vim.g.nord_italic and { fg = nord.teal, style = "italic" } or { fg = nord.teal },
    AerialModule = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" } or { fg = nord.darkest_white },
    AerialNamespace = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" }
      or { fg = nord.darkest_white },
    AerialNull = { fg = nord.glacier },
    AerialNumber = { fg = nord.purple },
    AerialObject = { fg = nord.glacier },
    AerialOperator = { fg = nord.glacier },
    AerialPackage = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" } or { fg = nord.darkest_white },
    AerialProperty = vim.g.nord_italic and { fg = nord.darkest_white, style = "italic" } or { fg = nord.blue },
    AerialString = vim.g.nord_italic and { fg = nord.green, style = "italic" } or { fg = nord.green },
    AerialStruct = { fg = nord.glacier },
    AerialTypeParameter = { fg = nord.blue },
    AerialVariable = { fg = nord.darkest_white, style = "bold" },
  }
  -- Options:

  -- Disable nvim-tree background
  if vim.g.nord_disable_background then
    plugins.NvimTreeNormal = { fg = nord.darkest_white, bg = nord.none }
  else
    plugins.NvimTreeNormal = { fg = nord.darkest_white, bg = nord.sidebar }
  end

  if vim.g.nord_enable_sidebar_background then
    plugins.NvimTreeNormal = { fg = nord.darkest_white, bg = nord.sidebar }
  else
    plugins.NvimTreeNormal = { fg = nord.darkest_white, bg = nord.none }
  end

  return plugins
end

return theme
