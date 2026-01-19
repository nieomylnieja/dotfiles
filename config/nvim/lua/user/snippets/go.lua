local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

return {
  -- Error handling snippet (higher priority)
  s(
    { trig = "ife", dscr = "if err != nil", priority = 1000 },
    fmt(
      [[
if err != nil {{
	{}
}}
{}]],
      {
        i(1, "return err"),
        i(0),
      }
    )
  ),

  -- If-else snippet (lower priority)
  s(
    { trig = "ifel", dscr = "if else", priority = 500 },
    fmt(
      [[
if {} {{
	{}
}} else {{
	{}
}}
{}]],
      {
        i(1, "condition"),
        i(2, "// true branch"),
        i(3, "// false branch"),
        i(0),
      }
    )
  ),
}
