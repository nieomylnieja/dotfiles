local M = {}

function M.setup()
  require("neotest").setup({
    adapters = {
      require("neotest-python")({
        dap = {
          justMyCode = false,
          console = "integratedTerminal",
        },
        args = { "--log-level", "DEBUG", "--quiet" },
        runner = "pytest",
      }),
      require("neotest-go")({
        experimental = {
          test_table = true,
        },
      }),
      require('neotest-jest')({}),
    },
    quickfix = {
      open = false,
    },
    output = {
      open_on_run = false,
    },
    consumers = {
      notify = M._notif_consumer,
    },
  })
end

function M._notif_consumer(client)
  client.listeners.results = function(adapter_id, results, partial)
    -- Partial results can be very frequent
    if partial then
      return
    end
    local failed = 0
    for _, res in pairs(results) do
      if res.status == "failed" then
        failed = failed + 1
      end
    end
    if failed > 0 then
      vim.notify("Tests failed!", "error")
    else
      vim.notify("Tests passed!", "info")
    end
  end
  return {}
end

return M
