local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  s(
    { trig = "module", dscr = "module directive" },
    fmt("module {}", {
      i(1, "example.com/module"),
    })
  ),

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
    { trig = "require", dscr = "require directive" },
    fmt("require {} {}", {
      i(1, "example.com/module"),
      i(2, "v1.0.0"),
    })
  ),

  s(
    { trig = "requireb", dscr = "require block" },
    fmt(
      [[
require (
	{} {}
)]],
      {
        i(1, "example.com/module"),
        i(2, "v1.0.0"),
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
    { trig = "exclude", dscr = "exclude directive" },
    fmt("exclude {} {}", {
      i(1, "example.com/module"),
      i(2, "v1.0.0"),
    })
  ),

  s(
    { trig = "retract", dscr = "retract directive" },
    fmt("retract {}", {
      i(1, "v1.0.0"),
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
