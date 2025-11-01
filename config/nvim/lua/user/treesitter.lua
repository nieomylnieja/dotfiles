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

      local parser_installed = pcall(vim.treesitter.get_parser, bufnr, parser_name)

      -- If not installed, install parser synchronously
      if not parser_installed then
        require("nvim-treesitter").install({ parser_name }):wait(30000) -- main branch syntax
        vim.notify("Installed parser: " .. parser_name, vim.log.levels.INFO, { title = "core/treesitter" })
      end

      -- Check so tree-sitter can see the newly installed parser
      parser_installed = pcall(vim.treesitter.get_parser, bufnr, parser_name)
      if not parser_installed then
        vim.notify(
          "Failed to get parser for " .. parser_name .. " after installation",
          vim.log.levels.WARN,
          { title = "core/treesitter" }
        )
        return
      end

      -- Start treesitter for this buffer
      vim.treesitter.start(bufnr, parser_name)

      -- This way injections Tree-sitter injections actually work.
      -- Otherwise, the semantic token has higher priority and overrides injection.
      vim.api.nvim_set_hl(0, "@lsp.type.string.go", {})
    end,
  })
end

return M
