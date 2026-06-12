local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  s(
    { trig = "go", dscr = "go directive" },
    fmt("go {}", {
      i(1, "1.26"),
    })
  ),

  s(
    { trig = "toolchain", dscr = "toolchain directive" },
    fmt("toolchain {}", {
      i(1, "go1.26.0"),
    })
  ),

  s(
    { trig = "use", dscr = "use directive" },
    fmt("use {}", {
      i(1, "./module"),
    })
  ),

  s(
    { trig = "useb", dscr = "use block" },
    fmt(
      [[
use (
	{}
)]],
      {
        i(1, "./module"),
      }
    )
  ),

  s(
    { trig = "replace", dscr = "replace directive" },
    fmt("replace {} => {}", {
      i(1, "example.com/module"),
      i(2, "../module"),
    })
  ),

  s(
    { trig = "godebug", dscr = "godebug directive" },
    fmt("godebug {}={}", {
      i(1, "default"),
      i(2, "go1.26"),
    })
  ),
}
