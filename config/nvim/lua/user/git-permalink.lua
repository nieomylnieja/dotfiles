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
  local origin_url, _ = string.gsub(origin, "git@(.+):(.+)%.git", "https://%1/%2")

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

M.open_line_commit = function()
  local file = vim.fn.expand("%:p")
  local line = vim.fn.line(".")

  -- Check if file is tracked by git
  local is_tracked = vim.fn.system("git ls-files --error-unmatch " .. vim.fn.shellescape(file) .. " 2>/dev/null")
  if vim.v.shell_error ~= 0 then
    print("File not tracked by git")
    return
  end

  -- Get commit hash for the line using git blame
  local blame_output = vim.trim(vim.fn.system(
    string.format("git blame -L %d,%d --porcelain %s", line, line, vim.fn.shellescape(file))
  ))

  if vim.v.shell_error ~= 0 then
    print("Failed to run git blame")
    return
  end

  -- Extract commit hash (first line of porcelain output)
  local commit_hash = blame_output:match("^([%w]+)")

  if not commit_hash or commit_hash == "0000000000000000000000000000000000000000" then
    print("Line not committed yet")
    return
  end

  -- Get remote URL
  local origin = vim.trim(vim.fn.system("git remote get-url --push origin"))
  local origin_url, _ = string.gsub(origin, "git@(.+):(.+)%.git", "https://%1/%2")

  -- Construct commit URL
  local commit_url = origin_url .. "/commit/" .. commit_hash

  print("Opening commit: " .. commit_hash:sub(1, 7))
  open_link(commit_url)
  return commit_url
end

return M
