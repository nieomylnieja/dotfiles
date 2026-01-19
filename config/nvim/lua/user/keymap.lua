local map = vim.keymap.set

-- Override gx to handle both URLs and files
map("n", "gx", function()
  local target = vim.fn.expand("<cfile>")

  -- If it's a URL, open directly
  if target:match("^https?://") then
    vim.ui.open(target)
    return
  end

  -- For files, resolve to absolute path relative to current buffer's directory
  local bufdir = vim.fn.expand("%:p:h")
  local filepath = vim.fs.normalize(bufdir .. "/" .. target)

  if vim.fn.filereadable(filepath) == 1 then
    vim.ui.open(filepath)
  else
    vim.notify("File not found: " .. filepath, vim.log.levels.WARN)
  end
end, { desc = "Open URL or file under cursor" })

-- Better up/down which works with wrapped lines.
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Use H and L for beginning/end of line.
map("n", "H", "^", { silent = true })
map("n", "L", "$", { silent = true })

-- Move to window using the <ctrl> hjkl keys
map("n", "<C-h>", "<C-w>h", { desc = "Go to left window", remap = true })
map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window", remap = true })
map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window", remap = true })
map("n", "<C-l>", "<C-w>l", { desc = "Go to right window", remap = true })

-- Resize window using <ctrl> arrow keys
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Move Lines
map("n", "<A-j>", "<cmd>m .+1<cr>==", { desc = "Move down" })
map("n", "<A-k>", "<cmd>m .-2<cr>==", { desc = "Move up" })
map("i", "<A-j>", "<esc><cmd>m .+1<cr>==gi", { desc = "Move down" })
map("i", "<A-k>", "<esc><cmd>m .-2<cr>==gi", { desc = "Move up" })
map("v", "<A-j>", ":m '>+1<cr>gv=gv", { desc = "Move down" })
map("v", "<A-k>", ":m '<-2<cr>gv=gv", { desc = "Move up" })

-- buffers
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })

-- Clear search with <esc>
map({ "i", "n" }, "<esc>", "<cmd>noh<cr><esc>", { desc = "Escape and clear hlsearch" })

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
map("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "Next search result" })
map("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next search result" })
map("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "Prev search result" })
map("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })
map("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev search result" })

-- better indenting, gv switches to last visual selection so you can indent many times
map("v", "<", "<gv")
map("v", ">", ">gv")

-- git permalink
map("n", "<leader>glc", "", {
  expr = true,
  desc = "Copy a git permalink",
  callback = function()
    require("user.git-permalink").create_copy(".")
  end,
})
map("v", "<leader>glc", "", {
  expr = true,
  desc = "Copy a git permalink",
  callback = function()
    require("user.git-permalink").create_copy("v")
  end,
})
map("n", "<leader>glo", "", {
  expr = true,
  desc = "Copy a git permalink and open it in a browser",
  callback = function()
    require("user.git-permalink").create_open(".")
  end,
})

-- spelling
map("n", "z=", "<cmd>:lua require'telescope.builtin'.spell_suggest{}<cr>", { desc = "Spelling suggestions" })

local wk = require("which-key")

map("n", "<leader>e", function()
  -- Workaround for https://github.com/nvim-tree/nvim-tree.lua/issues/2520.
  if vim.bo.filetype == "TelescopePrompt" then
    require("telescope.actions").close(vim.api.nvim_get_current_buf())
  end
  vim.cmd("NvimTreeToggle")
end, { noremap = true })

wk.add({
  { "<leader>f",  group = "Find" },
  { "<leader>fC", "<cmd>Telescope commands<cr>",               desc = "Commands" },
  { "<leader>fG", "<cmd>Telescope live_grep_dir<cr>",          desc = "Live grep on selected directory" },
  { "<leader>fH", "<cmd>Telescope highlights<cr>",             desc = "Find highlight groups" },
  { "<leader>fM", "<cmd>Telescope man_pages<cr>",              desc = "Man pages" },
  { "<leader>fR", "<cmd>Telescope registers<cr>",              desc = "Registers" },
  { "<leader>fb", "<cmd>Telescope buffers<cr>",                desc = "Buffers" },
  { "<leader>fc", "<cmd>Telescope git_branches<cr>",           desc = "Checkout branch" },
  { "<leader>ff", "<cmd>Telescope find_files hidden=true<cr>", desc = "Find file" },
  { "<leader>fg", "<cmd>Telescope live_grep<cr>",              desc = "Live grep" },
  { "<leader>fh", "<cmd>Telescope help_tags<cr>",              desc = "Find help" },
  { "<leader>fk", "<cmd>Telescope keymaps<cr>",                desc = "Keymaps" },
  { "<leader>fl", "<cmd>Telescope resume<cr>",                 desc = "Resume last search" },
  { "<leader>fp", "<Cmd>Telescope projects<CR>",               desc = "Projects" },
  { "<leader>fr", "<cmd>Telescope oldfiles<cr>",               desc = "Open recent file" },
  { "<leader>fs", "<Cmd>Telescope lsp_document_symbols<CR>",   desc = "LSP Symbols" },
  { "<leader>ft", "<cmd>TodoTelescope<cr>",                    desc = "TODO comments" },
})

wk.add({
  { "<leader>t",  group = "Trouble/Test" },
  { "<leader>tN", "<cmd>lua require('trouble').prev(nil)<cr>",                     desc = "Previous item" },
  { "<leader>tS", "<cmd>lua require('neotest').output_panel.open()<cr>",           desc = "Test Summary panel" },
  { "<leader>ta", "<cmd>lua require('neotest').run.run({vim.fn.getcwd()})<cr>",    desc = "Test Whole Project" },
  { "<leader>td", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",              desc = "Diagnostics" },
  { "<leader>tf", "<cmd>lua require('neotest').run.run({vim.fn.expand('%')})<cr>", desc = "Test File" },
  { "<leader>tl", "<cmd>Trouble loclist toggle<cr>",                               desc = "Location List" },
  { "<leader>tm", "<cmd>lua require('neotest').run.run()<cr>",                     desc = "Test Method" },
  { "<leader>tn", "<cmd>lua require('trouble').next(nil)<cr>",                     desc = "Next item" },
  { "<leader>to", "<cmd>lua require('neotest').output.open({enter=true})<cr>",     desc = "Output Window" },
  {
    "<leader>tp",
    "<cmd>lua require('neotest').run.run({vim.fn.fnamemodify(vim.fn.expand('%:p'),':h')})<cr>",
    desc = "Test Directory",
  },
  { "<leader>tq", "<cmd>Trouble qflist toggle<cr>",                             desc = "Quick Fix" },
  { "<leader>tr", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "References" },
  { "<leader>ts", "<cmd>lua require('neotest').summary.toggle()<cr>",           desc = "Test Summary" },
  { "<leader>tt", "<cmd>TodoTrouble<cr>",                                       desc = "TODO comments" },
  { "<leader>tw", "<cmd>Trouble diagnostics toggle<cr>",                        desc = "Workspace Diagnostics" },
})

-- Common kill function for bdelete and bwipeout
-- credits: based LunarVim which in turn is based on bbye and nvim-bufdel
local function buf_kill()
  local kill_command = "bd"
  local force = false

  local bufnr = vim.api.nvim_get_current_buf()
  local bufname = vim.api.nvim_buf_get_name(bufnr)

  local choice
  if vim.bo[bufnr].modified then
    choice = vim.fn.confirm(string.format([[Save changes to "%s"?]], bufname), "&Yes\n&No\n&Cancel")
    if choice == 1 then
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("w")
      end)
    elseif choice == 2 then
      force = true
    else
      return
    end
  end

  -- Get list of windows IDs with the buffer to close
  local windows = vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_buf(win) == bufnr
  end, vim.api.nvim_list_wins())

  if force then
    kill_command = kill_command .. "!"
  end

  -- Get list of active buffers
  local buffers = vim.tbl_filter(function(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
  end, vim.api.nvim_list_bufs())

  -- If there is only one buffer (which has to be the current one), vim will
  -- create a new buffer on :bd.
  -- For more than one buffer, pick the previous buffer (wrapping around if necessary)
  if #buffers > 1 and #windows > 0 then
    for i, v in ipairs(buffers) do
      if v == bufnr then
        local prev_buf_idx = i == 1 and #buffers or (i - 1)
        local prev_buffer = buffers[prev_buf_idx]
        for _, win in ipairs(windows) do
          vim.api.nvim_win_set_buf(win, prev_buffer)
        end
      end
    end
  end

  -- Check if buffer still exists, to ensure the target buffer wasn't killed
  -- due to options like bufhidden=wipe.
  if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted then
    vim.cmd(string.format("%s %d", kill_command, bufnr))
  end
end

map("n", "<leader>q", buf_kill, { desc = "Close Buffer", silent = true })

--- Returns the current file's directory as a relative path with /** glob suffix for spectre searches.
local function spectre_path()
  return vim.fn.fnamemodify(vim.fn.expand("%:h"), ":~:.") .. "/**"
end

wk.add({
  { "<leader>s", group = "Search/Replace" },
  {
    "<leader>ss",
    function()
      require("spectre").toggle({ path = spectre_path() })
    end,
    desc = "Toggle Spectre",
  },
  {
    "<leader>sw",
    function()
      require("spectre").open_visual({ select_word = true, path = spectre_path() })
    end,
    desc = "Search current word",
  },
  {
    "<leader>sp",
    '<cmd>lua require("spectre").open_file_search({select_word=true})<cr>',
    desc = "Search in current file",
  },
})
map("v", "<leader>sw", function()
  vim.cmd('noautocmd normal! "vy')
  require("spectre").open({ search_text = vim.fn.getreg("v"), path = spectre_path() })
end, { desc = "Search selection" })

-- Godbolt (C/C++ only)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp" },
  callback = function(ev)
    map("n", "<leader>gc", "<cmd>GodboltCompiler telescope<cr>", { buffer = ev.buf, desc = "Godbolt compile" })
    map(
      "v",
      "<leader>gc",
      ":GodboltCompiler telescope<cr>",
      { buffer = ev.buf, desc = "Godbolt compile selection" }
    )
  end,
})

-- Treesitter text objects
local function ts_select(key, query, desc)
  map({ "x", "o" }, key, function()
    require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
  end, { desc = desc })
end

ts_select("af", "@function.outer", "Select around function")
ts_select("if", "@function.inner", "Select inner function")
ts_select("ac", "@class.outer", "Select around class")
ts_select("ic", "@class.inner", "Select inner class")
ts_select("aa", "@parameter.outer", "Select around parameter")
ts_select("ia", "@parameter.inner", "Select inner parameter")

-- Treesitter movement
map({ "n", "x", "o" }, "]f", function()
  require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer", "textobjects")
end, { desc = "Next function start" })
map({ "n", "x", "o" }, "[f", function()
  require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer", "textobjects")
end, { desc = "Previous function start" })
map({ "n", "x", "o" }, "]c", function()
  require("nvim-treesitter-textobjects.move").goto_next_start("@class.outer", "textobjects")
end, { desc = "Next class start" })
map({ "n", "x", "o" }, "[c", function()
  require("nvim-treesitter-textobjects.move").goto_previous_start("@class.outer", "textobjects")
end, { desc = "Previous class start" })
