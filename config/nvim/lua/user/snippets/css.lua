local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s(
    { trig = "box", dscr = "box-sizing: border-box" },
    t({
      "* {",
      "  box-sizing: border-box;",
      "}",
    })
  ),
}
