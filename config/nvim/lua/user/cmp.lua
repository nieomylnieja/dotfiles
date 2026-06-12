local cmp = require("cmp")
local luasnip = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()
require("luasnip.loaders.from_lua").load({ paths = { vim.fn.stdpath("config") .. "/lua/user/snippets" } })
luasnip.config.setup({})

local go_doc_link_keyword_pattern = [[\%(\k\|\.\|/\)\+]]
local gomod_module_keyword_pattern = [[\%(\k\|[./-]\)\+]]

local gomod_module_source = {}

local function gomod_module_path_from_line(line)
  return line:match("^%s*require%s+([%w._~/-]+)%s+v")
    or line:match("^%s*replace%s+([%w._~/-]+)%s")
    or line:match("^%s*exclude%s+([%w._~/-]+)%s+v")
    or line:match("^%s*([%w._~/-]+)%s+v[%w.+-]+")
end

local function gomod_read_module_paths(dir)
  local paths = {}

  for _, filename in ipairs({ "go.mod", "go.sum" }) do
    local path = vim.fs.joinpath(dir, filename)
    if vim.fn.filereadable(path) == 1 then
      for _, line in ipairs(vim.fn.readfile(path)) do
        local module_path = gomod_module_path_from_line(line)
        if module_path and module_path:find(".", 1, true) then
          paths[module_path] = true
        end
      end
    end
  end

  return paths
end

function gomod_module_source:is_available()
  return vim.bo.filetype == "gomod" or vim.bo.filetype == "gowork"
end

function gomod_module_source:get_keyword_pattern()
  return gomod_module_keyword_pattern
end

function gomod_module_source:complete(_, callback)
  local filename = vim.api.nvim_buf_get_name(0)
  local dir = filename ~= "" and vim.fs.dirname(filename) or vim.fn.getcwd()
  local items = {}

  for module_path in pairs(gomod_read_module_paths(dir)) do
    table.insert(items, {
      label = module_path,
      kind = cmp.lsp.CompletionItemKind.Module,
    })
  end

  table.sort(items, function(a, b)
    return a.label < b.label
  end)

  callback({
    items = items,
    isIncomplete = false,
  })
end

cmp.register_source("gomod_modules", gomod_module_source)

local function in_go_doc_link_context(ctx)
  if vim.bo.filetype ~= "go" then
    return false
  end

  local before = ctx.cursor_before_line
  local comment_start = before:find("//", 1, true)
  if not comment_start then
    return false
  end

  local comment = before:sub(comment_start + 2)
  local open_link = comment:match("^.*()%[")
  if not open_link then
    return false
  end

  local close_link = comment:match("^.*()%]")
  if close_link and close_link > open_link then
    return false
  end

  return comment:sub(open_link):match("^%[[%w_./]*$") ~= nil
end

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
    ["<C-e>"] = cmp.mapping.abort(),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        local entry = cmp.get_selected_entry()
        if entry then
          cmp.confirm({ behavior = cmp.ConfirmBehavior.Insert, select = true })
        elseif luasnip.locally_jumpable(1) then
          luasnip.jump(1)
        else
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
        end
      elseif luasnip.expand_or_locally_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if luasnip.locally_jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = {
    { name = "nvim_lsp" },
    { name = "luasnip" },
    { name = "html-css" },
    { name = "path" },
    { name = "lazydev", group_index = 0 }, -- set group index to 0 to skip loading LuaLS completions
  },
  formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(_, vim_item)
      vim_item.kind = require("lspkind").symbolic(vim_item.kind, { mode = "symbol_text" })
      local strings = vim.split(vim_item.kind, "%s", { trimempty = true })
      local kind, menu = strings[1], strings[2]

      vim_item.kind = " " .. (kind or "") .. " "
      vim_item.menu = "    (" .. (menu or "") .. ")"
      vim_item.abbr = string.sub(vim_item.abbr, 1, 30)
      return vim_item
    end,
  },
})

cmp.setup.filetype("go", {
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
    {
      name = "buffer",
      keyword_pattern = go_doc_link_keyword_pattern,
      option = {
        keyword_pattern = go_doc_link_keyword_pattern,
      },
      entry_filter = function(_, ctx)
        return in_go_doc_link_context(ctx)
      end,
    },
    { name = "path" },
  }),
})

cmp.setup.filetype({ "gomod", "gowork" }, {
  sources = cmp.config.sources({
    { name = "luasnip" },
    { name = "gomod_modules" },
    { name = "nvim_lsp" },
    { name = "path" },
    {
      name = "buffer",
      keyword_pattern = gomod_module_keyword_pattern,
      option = {
        keyword_pattern = gomod_module_keyword_pattern,
      },
    },
  }),
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
  sources = {
    {
      name = "cmdline",
      option = {
        ignore_cmds = { "Man", "!" },
      },
    },
  },
})

-- DAP, only works with daps supporting 'supportsCompletionsRequest'.
cmp.setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
  sources = {
    { name = "dap" },
  },
})

-- Autopairs integration: auto-insert {} for Go structs
local cmp_autopairs = require("nvim-autopairs.completion.cmp")
local handlers = require("nvim-autopairs.completion.handlers")
cmp.event:on(
  "confirm_done",
  cmp_autopairs.on_confirm_done({
    filetypes = {
      ["*"] = {
        ["("] = {
          kind = {
            cmp.lsp.CompletionItemKind.Function,
            cmp.lsp.CompletionItemKind.Method,
          },
          handler = handlers["*"],
        },
      },
      go = {
        ["{"] = {
          kind = {
            cmp.lsp.CompletionItemKind.Keyword,
          },
          handler = function(char, item, bufnr, rules, commit_character)
            if item.label == "struct" or item.label == "interface" then
              handlers["*"](char, item, bufnr, rules, commit_character)
            end
          end,
        },
      },
    },
  })
)
