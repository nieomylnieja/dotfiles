local ls = require("luasnip")
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node

return {
  s(
    { trig = "css", dscr = "basic CSS setup" },
    t({
      ":root {",
      "  --base-font-size: 1rem;",
      "}",
      "/* set the box sizing to border-box for layouts */",
      "html {",
      "  box-sizing: border-box;",
      "}",
      "*,",
      "*::before,",
      "*::after {",
      "  box-sizing: inherit;",
      "}",
      "body {",
      "  font-size: var(--base-font-size);",
      "}",
      "/* make sure images don't exceed the width of the window */",
      "img {",
      "  max-width: 100%;",
      "}",
    })
  ),
}
