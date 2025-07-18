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
    config = function()
      local configs = require("nvim-treesitter.configs")
      configs.setup({
        ensure_installed = { "lua", "vim", "vimdoc", "go", "bash", "ocaml", "regex", "markdown_inline" },
        auto_install = true,
        sync_install = false,
        highlight = { enable = true },
        indent = { enable = true },
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
        "tailwindcss-language-server",
        "postgrestools",
        -- Linters/formatters
        "actionlint",
        "stylua",
        "luacheck",
        "goimports",
        "ruff",   -- Serves ass an LSP too.
        "shfmt",
        "shellcheck", -- For bashls
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
    branch = "0.1.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
      },
      "edolphin-ydf/goimpl.nvim",
    },
    config = function()
      local ts = require("telescope")
      ts.load_extension("fzf")
      ts.load_extension("goimpl")
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
    "stevearc/dressing.nvim",
    opts = {
      input = {
        win_options = {
          winblend = 10,
        },
      },
    },
  },
  -- I might not need it since nvim 0.10 comes with this functionality baked-in.
  -- {
  --   "numToStr/Comment.nvim",
  --   config = function()
  --     require("Comment").setup()
  --   end,
  -- },
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
        -- Use fast wrap with <M-e>
        fast_wrap = {},
      })
      require("cmp").event:on("confirm_done", require("nvim-autopairs.completion.cmp").on_confirm_done())
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
    dependencies = {
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
      "nvim-neotest/nvim-nio",
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
    "rcarriga/nvim-notify",
    config = function()
      require("notify").setup({
        background_colour = "#000000",
      })
    end,
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
    -- opts = {
    -- lsp = {
    --   override = {
    --     ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
    --     ["vim.lsp.util.stylize_markdown"] = true,
    --     ["cmp.entry.get_documentation"] = true,
    --   },
    -- },
    -- messages = {
    --   enabled = true,
    -- },
    -- routes = {
    --   {
    --     filter = {
    --       event = "msg_show",
    --       any = {
    --         { find = "%d+L, %d+B" },
    --         { find = "; after #%d+" },
    --         { find = "; before #%d+" },
    --         { find = "lines yanked" },
    --         { find = "fewer lines" },
    --       },
    --     },
    --     view = "mini",
    --   },
    -- },
    -- presets = {
    --   bottom_search = true,
    --   command_palette = true,
    --   long_message_to_split = true,
    --   lsp_doc_border = true,
    -- },
    -- },
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
  -- EVALUATION OVER --
  -- Once they have a better chat support I might reconsider.
  --
  -- {
  -- 	"codota/tabnine-nvim",
  -- 	build = {
  -- 		"./dl_binaries.sh",
  -- 		"cd chat/ && cargo build --release",
  -- 	},
  -- 	config = function()
  -- 		require("tabnine").setup({
  -- 			disable_auto_comment = true,
  -- 			accept_keymap = "<M-Tab>",
  -- 			dismiss_keymap = "<C-]>",
  -- 			debounce_ms = 800,
  -- 			-- suggestion_color = { gui = "#808080", cterm = 244 },
  -- 			exclude_filetypes = { "TelescopePrompt", "NvimTree" },
  -- 			log_file_path = nil, -- absolute path to Tabnine log file
  -- 		})
  -- 	end,
  -- },
  -- {
  -- 	"tzachar/cmp-tabnine",
  -- 	build = "./install.sh",
  -- 	dependencies = "hrsh7th/nvim-cmp",
  -- },
  {
    "NvChad/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup({})
    end,
  },
  {
    "ahmedkhalf/project.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" },
    config = function()
      require("project_nvim").setup({})
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
      require("nvim-tree").setup({
        sync_root_with_cwd = true,
        respect_buf_cwd = true,
        update_focused_file = {
          enable = true,
          update_root = true,
        },
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
    "olimorris/codecompanion.nvim",
    opts = {},
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("codecompanion").setup({
        adapters = {
          copilot = function()
            return require("codecompanion.adapters").extend("copilot", {
              schema = {
                model = {
                  default = "claude-sonnet-4",
                },
              },
            })
          end,
        },
        strategies = {
          chat = {
            adapter = "copilot",
          },
          inline = {
            adapter = "copilot",
          },
          cmd = {
            adapter = "copliot",
          },
        },
        extensions = {
          mcphub = {
            callback = "mcphub.extensions.codecompanion",
            opts = {
              show_result_in_chat = true, -- Show mcp tool results in chat
              make_vars = true,    -- Convert resources to #variables
              make_slash_commands = true, -- Add prompts as /slash commands
            },
          },
        },
      })
    end,
  },
  {
    "ravitemer/mcphub.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required for Job and HTTP requests
    },
    build = "npm install -g mcp-hub@latest",
    config = function()
      require("mcphub").setup()
    end,
  },
  {
    "OXY2DEV/markview.nvim",
    lazy = false,
    opts = {
      preview = {
        filetypes = { "markdown", "codecompanion" },
        ignore_buftypes = {},
      },
    },

    -- For blink.cmp's completion
    -- source
    -- dependencies = {
    --     "saghen/blink.cmp"
    -- },
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
}
