local map = vim.keymap.set

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

local wk = require("which-key")

map("n", "<leader>e", function()
  -- Workaround for https://github.com/nvim-tree/nvim-tree.lua/issues/2520.
  if vim.bo.filetype == "TelescopePrompt" then
    require("telescope.actions").close(vim.api.nvim_get_current_buf())
  end
  vim.cmd("NvimTreeToggle")
end, { noremap = true })

wk.register({
  f = {
    name = "+Find",
    b = { "<cmd>Telescope buffers<cr>", "Buffers" },
    c = { "<cmd>Telescope git_branches<cr>", "Checkout branch" },
    f = { "<cmd>Telescope find_files hidden=true<cr>", "Find file" },
    h = { "<cmd>Telescope help_tags<cr>", "Find help" },
    H = { "<cmd>Telescope highlights<cr>", "Find highlight groups" },
    M = { "<cmd>Telescope man_pages<cr>", "Man pages" },
    r = { "<cmd>Telescope oldfiles<cr>", "Open recent file" },
    R = { "<cmd>Telescope registers<cr>", "Registers" },
    g = { "<cmd>Telescope live_grep<cr>", "Live grep" },
    G = {
      function()
        require("telescope.builtin").live_grep({
          cwd = require("telescope.utils").buffer_dir(),
        })
      end,
      "Live grep on current directory",
    },
    k = { "<cmd>Telescope keymaps<cr>", "Keymaps" },
    C = { "<cmd>Telescope commands<cr>", "Commands" },
    l = { "<cmd>Telescope resume<cr>", "Resume last search" },
    t = { "<cmd>TodoTelescope<cr>", "TODO comments" },
    p = { "<Cmd>Telescope projects<CR>", "Projects" },
    s = { "<Cmd>Telescope lsp_document_symbols<CR>", "LSP Symbols" },
  },
}, { prefix = "<leader>" })

wk.register({
  t = {
    name = "+Trouble/Test",
    r = { "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", "References" },
    q = { "<cmd>Trouble qflist toggle<cr>", "Quick Fix" },
    l = { "<cmd>Trouble loclist toggle<cr>", "Location List" },
    d = { "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Diagnostics" },
    w = { "<cmd>Trouble diagnostics toggle<cr>", "Workspace Diagnostics" },
    t = { "<cmd>TodoTrouble<cr>", "TODO comments" },
    m = { "<cmd>lua require('neotest').run.run()<cr>", "Test Method" },
    f = { "<cmd>lua require('neotest').run.run({vim.fn.expand('%')})<cr>", "Test File" },
    a = { "<cmd>lua require('neotest').run.run({vim.fn.getcwd()})<cr>", "Test Whole Project" },
    p = {
      "<cmd>lua require('neotest').run.run({vim.fn.fnamemodify(vim.fn.expand('%:p'),':h')})<cr>",
      "Test Directory",
    },
    s = { "<cmd>lua require('neotest').summary.toggle()<cr>", "Test Summary" },
    S = { "<cmd>lua require('neotest').output_panel.open()<cr>", "Test Summary panel" },
    o = { "<cmd>lua require('neotest').output.open({enter=true})<cr>", "Output Window" },
  },
}, { prefix = "<leader>" })

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
