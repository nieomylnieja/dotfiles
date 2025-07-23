local M = {}

local function trim_prefix(s, prefix)
  if s:sub(1, #prefix) == prefix then
    return s:sub(#prefix + 1)
  else
    return s
  end
end

-- Send the link to your clipboard and print a message saying it was done.
local send_to_clipboard = function(permalink)
  print("Copied permalink to github")
  vim.fn.setreg("*", permalink)
  vim.fn.setreg("+", permalink)
end

-- Open the link in your default browser, naively.
local open_link = function(permalink)
  local os_name = vim.uv.os_uname().sysname
  local is_windows = vim.uv.os_uname().version:match("Windows")

  if os_name == "Darwin" then
    os.execute("open " .. permalink)
  elseif os_name == "Linux" then
    os.execute("xdg-open " .. permalink)
  elseif is_windows then
    os.execute("start " .. permalink)
  end
end

-- Create the link
--
-- @param mode either '.' or 'v'. Used by vim.fn.line
M.create_link = function(mode)
  local origin = vim.trim(vim.fn.system("git remote get-url --push origin"))
  local origin_url, _ = string.gsub(origin, "git@(.+):(.+)/(.+).git", "https://%1/%2/%3")

  local sha = vim.trim(vim.fn.system("git rev-parse HEAD"))
  local repo = trim_prefix(vim.api.nvim_buf_get_name(0), vim.fn.getcwd())
  local line_number = vim.fn.line(mode)
  local end_line_number = line_number
  if mode == "v" then
    end_line_number = vim.fn.line(".")
  end

  return origin_url .. "/blob/" .. sha .. repo .. "#L" .. line_number .. "-L" .. end_line_number
end

M.create_copy = function(mode)
  local permalink = M.create_link(mode)
  send_to_clipboard(permalink)
  return permalink
end

M.create_open = function(mode)
  local permalink = M.create_link(mode)
  open_link(permalink)
  return permalink
end

M.create_copy_open = function(mode)
  local permalink = M.create_link(mode)
  send_to_clipboard(permalink)
  open_link(permalink)
  return permalink
end

return M
