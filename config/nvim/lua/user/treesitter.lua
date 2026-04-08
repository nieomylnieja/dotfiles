local M = {}

-- Install and start parsers for nvim-treesitter.
-- Auto-install and start treesitter parser for any buffer with a registered filetype.
function M.install_and_start()
  vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
    callback = function(event)
      local bufnr = event.buf
      local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })

      if filetype == "" then
        return
      end

      -- Get parser name based on filetype
      -- WARNING: might return filetype (not helpful)
      local parser_name = vim.treesitter.language.get_lang(filetype)
      if not parser_name then
        return
      end

      local parser_configs = require("nvim-treesitter.parsers")
      if not parser_configs[parser_name] then
        return
      end

      -- Check for compiled .so directly; get_parser is lazy in Neovim 0.12+
      -- and no longer fails when the .so is missing.
      local ts_config = require("nvim-treesitter.config")
      local parser_dir = ts_config.get_install_dir("parser")
      local parser_so = vim.fs.joinpath(parser_dir, parser_name .. ".so")

      if not vim.uv.fs_stat(parser_so) then
        require("nvim-treesitter").install({ parser_name }):wait(30000)
        vim.notify("Installed parser: " .. parser_name, vim.log.levels.INFO, { title = "core/treesitter" })
      end

      if not vim.uv.fs_stat(parser_so) then
        vim.notify(
          "Failed to install parser for " .. parser_name,
          vim.log.levels.WARN,
          { title = "core/treesitter" }
        )
        return
      end

      vim.treesitter.start(bufnr, parser_name)

      -- This way injections Tree-sitter injections actually work.
      -- Otherwise, the semantic token has higher priority and overrides injection.
      vim.api.nvim_set_hl(0, "@lsp.type.string.go", {})
    end,
  })
end

return M
