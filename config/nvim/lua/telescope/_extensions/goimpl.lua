local actions = require("telescope.actions")
local state = require("telescope.actions.state")
local conf = require("telescope.config").values
local finders = require("telescope.finders")
local make_entry = require("telescope.make_entry")
local pickers = require("telescope.pickers")
-- ts_utils removed in nvim-treesitter main branch, using vim.treesitter instead
local channel = require("plenary.async.control").channel

local function prequire(mod)
  local ok, res = pcall(require, mod)
  if ok then
    return res
  end
  return nil
end
local plog = prequire("plenary.log")
local logger
if not plog then
  local emptyFun = function(_) end
  logger = {
    trace = emptyFun,
    debug = emptyFun,
    info = emptyFun,
    warn = emptyFun,
    error = emptyFun,
    fatal = emptyFun,
  }
else
  logger = plog.new({
    plugin = "goimpl",
    use_console = true,
    use_file = true,
  })
end

local ts = vim.treesitter
local tsq = vim.treesitter.query

local function _get_node_text(node, source, opts)
  return (ts.get_node_text or tsq.get_node_text)(node, source, opts)
end

local M = {}

-- Acording to LSP spec, if the client set "symbolKind.valueSet",
-- the client must handle it properly even if it receives a value outside the specification.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_documentSymbol
local function _get_symbol_kind_name(symbol_kind)
  return vim.lsp.protocol.SymbolKind[symbol_kind] or "Unknown"
end

-- containerName
--- Converts symbols to quickfix list items.
--- copyed from neovim runtime inorder to add the containerName from symbol
---
--@param symbols DocumentSymbol[] or SymbolInformation[]
local function interfaces_to_items(symbols, bufnr)
  --@private
  local function _interfaces_to_items(_symbols, _items, _bufnr)
    for _, symbol in ipairs(_symbols) do
      if symbol.location then -- SymbolInformation type
        local range = symbol.location.range
        local kind = _get_symbol_kind_name(symbol.kind)
        if kind == "Interface" then
          table.insert(_items, {
            filename = vim.uri_to_fname(symbol.location.uri),
            lnum = range.start.line + 1,
            col = range.start.character + 1,
            kind = kind,
            text = "[" .. kind .. "] " .. symbol.name,
            containerName = symbol.containerName,
          })
        end
      elseif symbol.selectionRange then -- DocumentSymbole type
        local kind = M._get_symbol_kind_name(symbol.kind)
        if kind == "Interface" then
          table.insert(_items, {
            filename = vim.api.nvim_buf_get_name(_bufnr),
            lnum = symbol.selectionRange.start.line + 1,
            col = symbol.selectionRange.start.character + 1,
            kind = kind,
            text = "[" .. kind .. "] " .. symbol.name,
            containerName = symbol.containerName,
          })
        end
        if symbol.children then
          for _, v in ipairs(_interfaces_to_items(symbol.children, _items, _bufnr)) do
            vim.list_extend(_items, v)
          end
        end
      end
    end
    return _items
  end
  return _interfaces_to_items(symbols, {}, bufnr)
end

local function get_workspace_symbols_requester(bufnr, opts)
  local cancel = function() end
  return function(prompt)
    local tx, rx = channel.oneshot()
    cancel()
    _, cancel = vim.lsp.buf_request(bufnr, "workspace/symbol", { query = prompt }, tx)

    -- Handle 0.5 / 0.5.1 handler situation
    local err, res = rx()
    assert(not err, err)

    local locations = interfaces_to_items(res or {}, bufnr) or {}
    return locations
  end
end

local function split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
    table.insert(t, str)
  end
  return t
end

local function sanitize_job_data(data)
  if not data then
    return {}
  end
  -- Because the nvim.stdout's data will have an extra empty line at end on some OS (e.g. maxOS), we should remove it.
  if data[#data] == "" then
    table.remove(data, #data)
  end
  if #data < 1 then
    return {}
  end
  return data
end

local interface_declaration_query = vim.treesitter.query.parse(
  "go",
  [[
(type_declaration
(type_spec
  type: (interface_type))
) @interface_declaration
]]
)

local generyc_type_name_parameters_query = vim.treesitter.query.parse(
  "go",
  [[
	[
(type_spec
  name: (type_identifier) @interface.generic.name
  type_parameters: (type_parameter_list) @interface.generic.type_parameters
  type: (interface_type) )
]
	]]
)

local type_parameter_name_query = vim.treesitter.query.parse(
  "go",
  [[(type_parameter_declaration
  name: (identifier) @type_parameter_name)
  ]]
)

local method_declaration_query = vim.treesitter.query.parse(
  "go",
  [[
(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      name: (identifier) @receiver_name
      type: (_) @receiver_full_type
    )
  )
) @method
]]
)

local function get_type_parameter_name_list(node, buf)
  local type_parameter_names = {}
  for _, tnode, _ in type_parameter_name_query:iter_captures(node, buf or 0) do
    type_parameter_names[#type_parameter_names + 1] = vim.treesitter.get_node_text(tnode, buf or 0)
  end

  return type_parameter_names
end

local function find_existing_receiver_name(type_name)
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = vim.treesitter.get_parser(bufnr, "go")
  if not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end
  local root = tree:root()

  for id, node in method_declaration_query:iter_captures(root, bufnr) do
    local capture_name = method_declaration_query.captures[id]

    if capture_name == "method" then
      local receiver_name = nil
      local receiver_full_type = nil
      local receiver_type_node = nil

      for mid, mnode in method_declaration_query:iter_captures(node, bufnr) do
        local mcapture = method_declaration_query.captures[mid]
        if mcapture == "receiver_name" then
          receiver_name = vim.treesitter.get_node_text(mnode, bufnr)
        elseif mcapture == "receiver_full_type" then
          receiver_full_type = vim.treesitter.get_node_text(mnode, bufnr)
          receiver_type_node = mnode
        end
      end

      if receiver_full_type then
        local is_pointer = receiver_type_node:type() == "pointer_type"
        local base_type = receiver_full_type

        -- Strip pointer prefix if present
        if is_pointer then
          base_type = base_type:match("^%*(.+)") or base_type
        end

        -- Check if this matches our type (with or without generic parameters)
        if base_type == type_name or base_type:match("^" .. type_name .. "%[") then
          return {
            name = receiver_name,
            is_pointer = is_pointer,
          }
        end
      end
    end
  end

  return nil
end

local function format_type_parameter_name_list(type_parameter_names)
  if #type_parameter_names == 0 then
    return ""
  end
  return "[" .. table.concat(type_parameter_names, ", ") .. "]"
end

local function load_file_to_buffer(filepath, buf)
  local file = io.open(filepath, "r")
  if not file then
    logger.info("file not found: " .. filepath)
    return false
  end

  local content = file:read("*all")
  file:close()
  logger.info(content)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
  return true
end

local function get_interface_generic_type_parameters(file, interface_name)
  local buf = vim.api.nvim_create_buf(false, true)
  local ok, errmsg = pcall(vim.api.nvim_set_option_value, "filetype", "go", { buf = buf })
  if not ok then
    logger.info(("can't set filetype to 'go' (%s). Formatting is canceled"):format(errmsg))
    return ""
  end

  if not load_file_to_buffer(file, buf) then
    return ""
  end

  local parser = vim.treesitter.get_parser(buf, "go")
  if parser == nil then
    logger.error("Go parser is nil")
    return ""
  end
  local tree = parser:parse()[1]
  local root = tree:root()

  for _, node, _ in interface_declaration_query:iter_captures(root, buf) do
    local is_check_interface = false
    for iid, inode, _ in generyc_type_name_parameters_query:iter_captures(node, buf) do
      local name = generyc_type_name_parameters_query.captures[iid]
      if name == "interface.generic.name" then
        local current_interface_name = vim.treesitter.get_node_text(inode, buf)
        if current_interface_name == interface_name then
          is_check_interface = true
        end
      end
    end

    if is_check_interface then
      for iid, inode, _ in generyc_type_name_parameters_query:iter_captures(node, buf) do
        local name = generyc_type_name_parameters_query.captures[iid]
        if name == "interface.generic.type_parameters" then
          local type_parameter_names = get_type_parameter_name_list(inode, buf)

          vim.api.nvim_buf_delete(buf, { force = true })
          return format_type_parameter_name_list(type_parameter_names)
        end
      end
    end
  end

  vim.api.nvim_buf_delete(buf, { force = true })

  return ""
end

local function run_goimpl_command(dirname, rec_name, rec_type, interface)
  local cmd = string.format('impl -comments=false -dir=%s "%s %s" "%s"', dirname, rec_name, rec_type, interface)
  logger.info(cmd)
  local data = vim.fn.systemlist(cmd)
  return sanitize_job_data(data)
end

local function goimpl(tsnode, package_name, iface_name, type_parameter_list)
  local rec_type = _get_node_text(tsnode, 0)
  local base_type_name = rec_type

  -- Try to find an existing receiver name and pointer preference from existing methods
  local existing_receiver = find_existing_receiver_name(base_type_name)
  local rec_name
  local use_pointer = true -- Default to pointer receiver

  if existing_receiver then
    rec_name = existing_receiver.name
    use_pointer = existing_receiver.is_pointer
  else
    -- Fall back to generating one from the type name
    rec_name = string.lower(string.sub(rec_type, 1, 2))
  end

  local type_parameter_names = format_type_parameter_name_list(get_type_parameter_name_list(tsnode:parent()))
  rec_type = rec_type .. type_parameter_names

  -- get the package source directory
  local dirname = vim.fn.fnameescape(vim.fn.expand("%:p:h"))

  local pointer_prefix = use_pointer and "*" or ""
  local data = run_goimpl_command(
    dirname,
    rec_name,
    pointer_prefix .. rec_type,
    package_name .. "." .. iface_name .. type_parameter_list
  )
  if not data or #data == 0 then
    return
  end

  -- if we didn't find the '$packageName.$interface' type, then try without the packageName
  -- this works for instance, in a main package
  if string.find(data[1], "unrecognized interface:") or string.find(data[1], "couldn't find") then
    data = run_goimpl_command(dirname, rec_name, pointer_prefix .. rec_type, iface_name .. type_parameter_list)
    if not data or #data == 0 then
      return
    end
  end

  local _, _, pos, _ = tsnode:parent():parent():range()
  pos = pos + 1
  vim.fn.append(pos, "") -- insert an empty line
  pos = pos + 1
  vim.fn.append(pos, data)
end

M.goimpl = function(opts)
  opts = opts or {}
  local curr_bufnr = vim.api.nvim_get_current_buf()

  local tsnode = vim.treesitter.get_node()
  if tsnode == nil then
    return
  end
  if
      tsnode:type() ~= "type_identifier"
      or tsnode:parent():type() ~= "type_spec"
      or tsnode:parent():parent():type() ~= "type_declaration"
  then
    print("No type identifier found under cursor")
    return
  end

  pickers
      .new(opts, {
        prompt_title = "Go Impl",
        finder = finders.new_dynamic({
          entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
          fn = get_workspace_symbols_requester(curr_bufnr, opts),
        }),
        previewer = conf.qflist_previewer(opts),
        sorter = conf.generic_sorter(),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            local entry = state.get_selected_entry()
            actions.close(prompt_bufnr)
            if not entry then
              return
            end

            -- if prompt is eg: sort.Interface, the symbol_name will contain the sort package name,
            -- so only use the real interface name
            local symbol_name = split(entry.symbol_name, ".")
            symbol_name = symbol_name[#symbol_name]

            local type_parameter_list = get_interface_generic_type_parameters(entry.filename, symbol_name)

            goimpl(tsnode, entry.value.containerName, symbol_name, type_parameter_list)
          end)
          return true
        end,
      })
      :find()
end

return require("telescope").register_extension({
  exports = {
    goimpl = M.goimpl,
  },
})
