local M = {
  ensure_installed = {}
}

function M.setup()
  vim.api.nvim_create_user_command("NullLsInstall", function()
    if #vim.lsp.get_active_clients() == 0 then
      return
    end
    -- No need to run again:
    -- 	 registry.refresh(vim.schedule_wrap(ensure_installed))
    -- It's already done by lvim core code, it's enough to just wait for the
    -- API to load, thus the schedule_wrap.
    for _, pkg_name in pairs(M.ensure_installed) do
      M._ensure_installed(pkg_name)
    end
  end, { desc = 'Install one or more null-ls sources.' })
end

---@param pkg_name string
function M._ensure_installed(pkg_name)
  if not registry.has_package(pkg_name) then
    vim.notify(
      string.format("[null-ls] %s is not supported for Mason installation", pkg_name),
      vim.log.levels.ERROR)
    return
  end
  local ok, pkg = pcall(registry.get_package, pkg_name)
  if not ok then
    vim.notify(
      string.format("[null-ls] error encountered when getting the %s pkg for Mason installation", pkg_name),
      vim.log.levels.ERROR)
    return
  end
  if pkg:is_installed() then
    return
  end
  vim.notify(("[null-ls] installing %s"):format(pkg.name))
  pkg:install():once("closed", vim.schedule_wrap(function()
    if pkg:is_installed() then
      vim.notify(("[null-ls] %s was installed"):format(pkg.name))
    end
  end))
end

return M
