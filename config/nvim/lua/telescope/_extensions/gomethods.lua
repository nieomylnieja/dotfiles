local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")

local ts = vim.treesitter
local tsq = vim.treesitter.query

local function get_node_text(node, source, opts)
  return (ts.get_node_text or tsq.get_node_text)(node, source, opts)
end

local function symbol_name_from_item(item)
  local text = item.text or ""
  return text:match("^%[[^%]]+%]%s+(.+)$") or text
end

local function method_matches_type(method_name, type_name)
  return method_name:match("^" .. type_name .. "%.[_%a][_%w]*$") ~= nil
      or method_name:match("%." .. type_name .. "%.[_%a][_%w]*$") ~= nil
end

local function get_identifier_under_cursor(bufnr)
  local node = vim.treesitter.get_node()
  while node do
    local node_type = node:type()
    if node_type == "type_identifier" or node_type == "identifier" then
      local text = get_node_text(node, bufnr)
      if text:match("^[_%a][_%w]*$") then
        return text
      end
      return nil
    end
    node = node:parent()
  end
  return nil
end

local function gomethods(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local type_name = get_identifier_under_cursor(bufnr)
  if not type_name then
    vim.notify("No Go type identifier found under cursor", vim.log.levels.WARN)
    return
  end

  vim.lsp.buf_request(bufnr, "workspace/symbol", { query = type_name }, function(err, result, ctx)
    if err then
      vim.notify(err.message or tostring(err), vim.log.levels.ERROR)
      return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local locations = vim.lsp.util.symbols_to_items(result or {}, bufnr, client and client.offset_encoding) or {}
    locations = vim.tbl_filter(function(item)
      if item.kind ~= "Method" then
        return false
      end
      return method_matches_type(symbol_name_from_item(item), type_name)
    end, locations)

    if vim.tbl_isempty(locations) then
      vim.notify("No Go methods found for " .. type_name, vim.log.levels.WARN)
      return
    end

    pickers
        .new(opts, {
          prompt_title = "Go Methods: " .. type_name,
          finder = finders.new_table({
            results = locations,
            entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
          }),
          previewer = conf.qflist_previewer(opts),
          sorter = conf.prefilter_sorter({
            tag = "symbol_type",
            sorter = conf.generic_sorter(opts),
          }),
        })
        :find()
  end)
end

return require("telescope").register_extension({
  exports = {
    gomethods = gomethods,
  },
})
