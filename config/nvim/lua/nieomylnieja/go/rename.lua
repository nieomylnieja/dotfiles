local rename = function ()
  local vfn = vim.fn

  local fname = vfn.expand("%:p")
  local old_id = vfn.expand("<cword>")
  local prompt = vfn.printf("gorename '%s' to (may take a while) :", old_id)
  local new_id = vfn.input(prompt, old_id)
  local byte_offset = vfn.wordcount().cursor_bytes
  local offset = string.format("%s:#%i", fname, byte_offset)

  vfn.jobstart({ "gorename", "-offset", offset, "-to", new_id }, {
    on_stdout = function(_, data, _)
      local result = vim.json.decode(data)
      if result.errors ~= nil or result.lines == nil or result["start"] == nil or result["start"] == 0 then
        vim.notify("failed to rename" .. vim.inspect(result), vim.lsp.log_levels.ERROR)
      end
      vim.notify("renamed to " .. new_id, vim.lsp.log_levels.DEBUG)
    end,
  })
end

return rename
