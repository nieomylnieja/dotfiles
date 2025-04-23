local _notif_consumer = function(client)
  client.listeners.results = function(_, results, partial)
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
      vim.notify("Tests failed!", vim.log.levels.ERROR)
    else
      vim.notify("Tests passed!", vim.log.levels.INFO)
    end
  end
  return {}
end

local neotest = require("neotest")

neotest.setup({
  adapters = {
    require("neotest-golang")({
      go_test_args = { "-v", "-count=1" },
      log_level = vim.log.levels.WARN,
      sanitize_output = true,
    }),
  },
  consumers = {
    notify = _notif_consumer,
  },
  output = {
    open_on_run = false,
  },
})
