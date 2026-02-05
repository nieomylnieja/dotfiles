return {
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        theme = require("user.colors.lualine"),
        icons_enabled = false,
        component_separators = "|",
        section_separators = "",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = {},
        lualine_x = {},
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 1000
    end,
    opts = {
      win = {
        border = "none",
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    branch = "main",
    config = function()
      local ts = require("nvim-treesitter")
      ts.install({
        "lua",
        "vim",
        "vimdoc",
        "go",
        "bash",
        "regex",
        "markdown",
        "markdown_inline",
        "sql",
        "json",
        "yaml",
        "asm",
        "c",
      })
      require("user.treesitter").install_and_start()
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    init = function()
      -- Disable entire built-in ftplugin mappings to avoid conflicts.
      -- See https://github.com/neovim/neovim/tree/master/runtime/ftplugin for built-in ftplugins.
      vim.g.no_plugin_maps = true
    end,
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          lookahead = true,
          include_surrounding_whitespace = false,
        },
        move = {
          set_jumps = true,
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
    },
    config = function()
      require("user.lsp").setup()
    end,
  },
  {
    "nvimtools/none-ls.nvim",
    lazy = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "davidmh/cspell.nvim",
      "nvimtools/none-ls-extras.nvim",
    },
  },
  {
    -- Autocompletion
    "hrsh7th/nvim-cmp",
    dependencies = {
      -- Snippet Engine & its associated nvim-cmp source
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      -- Adds LSP completion capabilities
      "hrsh7th/cmp-nvim-lsp",
      -- Adds a number of user-friendly snippets
      "rafamadriz/friendly-snippets",
      -- Ready to go LSP symbols
      "onsails/lspkind.nvim",
      -- Other
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "hrsh7th/cmp-buffer",
      "rcarriga/cmp-dap",
    },
    config = function()
      require("user.cmp")
    end,
  },

  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {
      ensure_installed = {
        -- LSP
        "lua-language-server",
        "gopls",
        "yaml-language-server",
        "json-lsp",
        "pyright",
        "typescript-language-server",
        "nil",
        "bash-language-server",
        "terraform-ls",
        "templ",
        "html-lsp",
        "htmx-lsp",
        "css-lsp",
        "tailwindcss-language-server",
        "postgres-language-server",
        "ansible-language-server",
        "clangd",
        "asm-lsp",
        -- Linters/formatters
        "actionlint",
        "stylua",
        "luacheck",
        "goimports",
        "ruff",   -- Serves ass an LSP too.
        "shfmt",
        "shellcheck", -- For bashls
        "gofumpt",
        "cspell",
        "golangci-lint",
        -- Code Actions
        "gomodifytags",
        "impl",
        -- DAP
        -- "delve", WARNING: Sometimes I want to run it separately.
        -- "debugpy",
      },
      ui = { border = "rounded" },
    },
    ---@param opts MasonSettings | {ensure_installed: string[]}
    config = function(_, opts)
      require("mason").setup(opts)
      local mr = require("mason-registry")
      mr:on("package:install:success", function()
        vim.defer_fn(function()
          -- trigger FileType event to possibly load this newly installed programs.
          require("lazy.core.handler.event").trigger({
            event = "FileType",
            buf = vim.api.nvim_get_current_buf(),
          })
        end, 100)
      end)
      local function ensure_installed()
        for _, tool in ipairs(opts.ensure_installed) do
          local p = mr.get_package(tool)
          if not p:is_installed() then
            p:install()
          end
        end
      end
      if mr.refresh then
        mr.refresh(ensure_installed)
      else
        ensure_installed()
      end
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    branch = "master",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
    },
    config = function()
      local ts = require("telescope")
      ts.load_extension("fzf")
      require("telescope._extensions.goimpl")
      require("telescope._extensions.env")
      require("telescope._extensions.live_grep_dir")
      ts.load_extension("env")
      ts.load_extension("live_grep_dir")
      ts.setup({
        pickers = {
          find_files = {
            find_command = { "fd", "--type", "f", "--strip-cwd-prefix" },
          },
          live_grep = {
            show_line = false,
          },
          lsp_definitions = {
            show_line = false,
          },
          lsp_implementations = {
            show_line = false,
          },
          lsp_references = {
            include_declaration = false,
            show_line = false,
          },
          lsp_document_symbols = {
            show_line = false,
          },
        },
      })
    end,
  },
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
  {
    "nvim-pack/nvim-spectre",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("spectre").setup({
        use_trouble_qf = true,
      })
    end,
  },
  {
    "stevearc/dressing.nvim",
    opts = {
      input = {
        win_options = {
          winblend = 10,
        },
      },
    },
  },
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "TroubleToggle", "Trouble" },
    opts = {
      focus = true,
      warn_no_results = false,
      open_no_results = true,
    },
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    dependencies = { "hrsh7th/nvim-cmp" },
    config = function()
      require("nvim-autopairs").setup({
        fast_wrap = {},
      })
    end,
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    opts = {
      indent = {
        char = "▏",
        tab_char = "▏",
      },
      scope = {
        show_start = false,
        show_end = false,
      },
      exclude = {
        buftypes = {
          "terminal",
          "nofile",
        },
        filetypes = {
          "help",
          "alpha",
          "dashboard",
          "neo-tree",
          "Trouble",
          "lazy",
          "mason",
          "notify",
          "toggleterm",
        },
      },
    },
    main = "ibl",
  },
  {
    "RRethy/vim-illuminate",
    config = function()
      require("illuminate").configure({
        providers = {
          "lsp",
          "treesitter",
          "regex",
        },
        filetypes_denylist = {
          "alpha",
          "NvimTree",
          "neogitstatus",
          "Trouble",
          "Outline",
          "toggleterm",
          "DressingSelect",
          "TelescopePrompt",
        },
        under_cursor = false,
      })
    end,
  },
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({})
    end,
  },
  {
    "nvim-neotest/neotest",
    lazy = true,
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "antoinemadec/FixCursorHold.nvim",
      -- Adapters
      {
        "fredrikaverpil/neotest-golang",
        dependencies = {
          "leoluz/nvim-dap-go",
          "uga-rosa/utf8.nvim", -- For sanitize_output option to work
        },
      },
    },
    config = function()
      require("user.neotest")
    end,
  },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {},
      },
      "leoluz/nvim-dap-go",
      "mfussenegger/nvim-dap-python",
    },
    config = function()
      require("user.dap")
    end,
  },
  -- {
  --   "leoluz/nvim-dap-go",
  --   config = function()
  --     require("dap-go").setup({
  --       dap_configurations = {
  --         {
  --           type = "go",
  --           name = "Debug (Build Flags & Arguments)",
  --           request = "launch",
  --           program = "${file}",
  --           args = require("dap-go").get_arguments,
  --         },
  --       },
  --     })
  --   end,
  -- },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    opts = {
      notify = {
        enabled = false,
      },
      messages = {
        enabled = false,
      },
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      routes = {
        {
          filter = {
            event = "msg_show",
            any = {
              { find = "%d+L, %d+B" },
              { find = "; after #%d+" },
              { find = "; before #%d+" },
              { find = "lines yanked" },
              { find = "fewer lines" },
              { find = "more lines" },
              { find = "line less" },
              { find = "Already at" },
              { find = "written" },
            },
          },
          opts = { skip = true },
        },
      },
    },
    keys = {
      {
        "<S-Enter>",
        function()
          require("noice").redirect(vim.fn.getcmdline())
        end,
        mode = "c",
        desc = "Redirect Cmdline",
      },
      {
        "<leader>snl",
        function()
          require("noice").cmd("last")
        end,
        desc = "Noice Last Message",
      },
      {
        "<leader>snh",
        function()
          require("noice").cmd("history")
        end,
        desc = "Noice History",
      },
      {
        "<leader>sna",
        function()
          require("noice").cmd("all")
        end,
        desc = "Noice All",
      },
      {
        "<leader>snd",
        function()
          require("noice").cmd("dismiss")
        end,
        desc = "Dismiss All",
      },
      {
        "<c-f>",
        function()
          if not require("noice.lsp").scroll(4) then
            return "<c-f>"
          end
        end,
        silent = true,
        expr = true,
        desc = "Scroll forward",
        mode = { "i", "n", "s" },
      },
      {
        "<c-b>",
        function()
          if not require("noice.lsp").scroll(-4) then
            return "<c-b>"
          end
        end,
        silent = true,
        expr = true,
        desc = "Scroll backward",
        mode = { "i", "n", "s" },
      },
    },
  },
  {
    "NvChad/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup({})
    end,
  },
  {
    "DrKJeff16/project.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
    config = function()
      require("project").setup({})
      require("telescope").load_extension("projects")
    end,
  },
  {
    "sindrets/diffview.nvim",
    config = function()
      require("diffview").setup({
        enhanced_diff_hl = true,
      })
    end,
  },
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    opts = {
      highlights = require("user.colors.bufferline").highlights,
      options = {
        offsets = {
          {
            filetype = "NvimTree",
            text = "Tree",
            highlight = "NvimTreeNormal",
            text_align = "left",
          },
        },
      },
    },
  },
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      local toggleterm = require("toggleterm")
      toggleterm.setup({
        size = 20,
        open_mapping = [[<c-\>]],
        direction = "float",
        shell = vim.o.shell,
        float_opts = {
          border = "curved",
          winblend = 0,
          highlights = {
            border = "Normal",
            background = "Normal",
          },
        },
      })

      function _G.set_terminal_keymaps()
        local opts = { noremap = true }
        vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
        vim.api.nvim_buf_set_keymap(0, "t", "jk", [[<C-\><C-n>]], opts)
        vim.api.nvim_buf_set_keymap(0, "t", "<C-h>", [[<C-\><C-n><C-W>h]], opts)
        vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", [[<C-\><C-n><C-W>j]], opts)
        vim.api.nvim_buf_set_keymap(0, "t", "<C-k>", [[<C-\><C-n><C-W>k]], opts)
        vim.api.nvim_buf_set_keymap(0, "t", "<C-l>", [[<C-\><C-n><C-W>l]], opts)
      end

      vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")
    end,
  },
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local api = require("nvim-tree.api")
      local function on_attach(bufnr)
        local function opts(desc)
          return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
        end
        api.config.mappings.default_on_attach(bufnr)
        vim.keymap.set("n", "H", function()
          api.tree.toggle_hidden_filter()
          api.tree.toggle_gitignore_filter()
        end, opts("Toggle Hidden & Gitignored"))
        -- Replace C-X with C-H for horizontal split
        vim.keymap.del("n", "<C-x>", { buffer = bufnr })
        vim.keymap.set("n", "<C-h>", api.node.open.horizontal, opts("Open: Horizontal Split"))
      end
      require("nvim-tree").setup({
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        update_focused_file = {
          enable = true,
          update_root = true,
        },
        filters = {
          dotfiles = true,
          git_ignored = true,
        },
        on_attach = on_attach,
      })
    end,
  },
  {
    "tpope/vim-fugitive",
    dependencies = { "tpope/vim-rhubarb" },
  },
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown", "plantuml", "mermaid" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    config = function()
      require("user.markdown-preview")
    end,
  },
  {
    "windwp/nvim-ts-autotag",
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },
  {
    "bullets-vim/bullets.vim",
  },
  {
    "folke/lazydev.nvim",
    ft = "lua", -- only load on lua files
    opts = {
      library = {
        -- See the configuration section for more details
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "supermaven-inc/supermaven-nvim",
    config = function()
      require("supermaven-nvim").setup({
        keymaps = {
          accept_suggestion = "<S-Tab>",
          clear_suggestion = "<C-]>",
          accept_word = "<C-j>",
        },
      })
    end,
  },
  {
    "Jezda1337/nvim-html-css",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("html-css"):setup()
    end,
  },
  {
    "p00f/godbolt.nvim",
    config = function()
      require("godbolt").setup({
        quickfix = {
          enable = true,
          auto_open = true,
        },
      })
    end,
  },
}
