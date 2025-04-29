local cmp = require("cmp")
local luasnip = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()
luasnip.config.setup({})

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-d>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete({}),
    ["<C-e>"] = cmp.mapping.close(),
    ["<CR>"] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = true,
    }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        local entry = cmp.get_selected_entry()
        if not entry then
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
        elseif luasnip.expand_or_locally_jumpable() then
        else
          cmp.confirm()
        end
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.locally_jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "copilot" },
    { name = "path" },
    { name = "lazydev", group_index = 0 }, -- set group index to 0 to skip loading LuaLS completions
  },
  formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(entry, vim_item)
      vim_item.kind = require("lspkind").symbolic(vim_item.kind, { mode = "symbol_text" })
      local strings = vim.split(vim_item.kind, "%s", { trimempty = true })
      local kind, menu = strings[1], strings[2]
      if entry.source.name == "cmp_tabnine" or entry.source.name == "copilot" then
        local detail = (entry.completion_item.labelDetails or {}).detail
        kind = "󱙺"
        if detail and detail:find(".*%%.*") then
          menu = detail
        end
        if (entry.completion_item.data or {}).multiline then
          menu = menu .. " " .. "[ML]"
        end
      end

      vim_item.kind = " " .. (kind or "") .. " "
      vim_item.menu = "    (" .. (menu or "") .. ")"
      vim_item.abbr = string.sub(vim_item.abbr, 1, 30)
      return vim_item
    end,
  },
})

-- `/` cmdline setup.
cmp.setup.cmdline("/", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = "buffer" },
  },
})

-- `:` cmdline setup.
cmp.setup.cmdline(":", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = "path" },
  }, {
    {
      name = "cmdline",
      option = {
        ignore_cmds = { "Man", "!" },
      },
    },
  }),
})

-- DAP, only works with daps supporting 'supportsCompletionsRequest'.
cmp.setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
  sources = {
    { name = "dap" },
  },
})
