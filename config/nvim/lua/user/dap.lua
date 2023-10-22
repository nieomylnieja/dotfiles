local dap = require("dap")
local dapui = require("dapui")

dapui.setup({
  controls = {
    element = "scopes",
  },
  expand_lines = false,
  layouts = { {
    elements = { {
      id = "repl",
      size = 0.25
    }, {
      id = "breakpoints",
      size = 0.25
    }, {
      id = "stacks",
      size = 0.25
    }, {
      id = "watches",
      size = 0.25
    } },
    position = "left",
    size = 40
  }, {
    elements = { {
      id = "scopes",
      size = 1
    } },
    position = "bottom",
    size = 20
  } },
})

vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapBreakpointCondition", { text = "", texthl = "Debug", linehl = "", numhl = "" })
vim.fn.sign_define("DapBreakpointRejected", { text = "", texthl = "Debug", linehl = "", numhl = "" })

dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open({}) end
dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close({}) end
dap.listeners.before.event_exited["dapui_config"] = function() dapui.close({}) end

require("dap-go").setup()

---@param config {args?:string[]|fun():string[]?}
local function dap_get_args(config)
  local args = type(config.args) == "function" and (config.args() or {}) or config.args or {}
  config = vim.deepcopy(config)
  ---@cast args string[]
  config.args = function()
    local new_args = vim.fn.input("Run with args: ", table.concat(args, " "))
    return vim.split(vim.fn.expand(new_args), " ")
  end
  return config
end

require("which-key").register({
  d = {
    name = "+Debug",
    b = { function() dap.toggle_breakpoint() end, "Toggle Breakpoint" },
    d = { function()
      local ft = vim.bo.filetype
      if ft == "go" then
        require("dap-go").debug_test()
      else
        vim.notify("unsupported DAP for running test", vim.log.levels.ERROR)
      end
    end, "Debug test" },
    B = { function() dap.set_breakpoint(vim.fn.input('Breakpoint condition: ')) end, "Breakpoint Condition" },
    c = { function() dap.continue() end, "Continue" },
    a = { function() dap.continue({ before = dap_get_args }) end, "Run with Args" },
    C = { function() dap.run_to_cursor() end, "Run to Cursor" },
    g = { function() dap.goto_() end, "Go to line (no execute)" },
    i = { function() dap.step_into() end, "Step Into" },
    j = { function() dap.down() end, "Down" },
    k = { function() dap.up() end, "Up" },
    l = { function() dap.run_last() end, "Run Last" },
    o = { function() dap.step_out() end, "Step Out" },
    O = { function() dap.step_over() end, "Step Over" },
    p = { function() dap.pause() end, "Pause" },
    r = { function() dap.repl.toggle() end, "Toggle REPL" },
    s = { function() dap.session() end, "Session" },
    t = { function() dap.terminate() end, "Terminate" },
    w = { function() require("dap.ui.widgets").hover() end, "Widgets" },
  }
}, { prefix = "<leader>" })
