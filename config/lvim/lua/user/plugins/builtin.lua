-- After changing plugin config exit and reopen LunarVim
lvim.builtin.alpha.mode = "dashboard"
lvim.builtin.nvimtree.setup.view.side = "left"
lvim.builtin.nvimtree.setup.renderer.icons.show.git = false
lvim.builtin.treesitter.ensure_installed = "all"
lvim.builtin.dap.breakpoint_rejected.text = ""
lvim.builtin.dap.on_config_done = function(dap)
  dap.listeners.after.event_initialized["dapui_config"] = require("dapui").open
end
