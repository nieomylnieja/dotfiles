The purpose of this document is to gather all the plugins I use and try to
document them in hopes of keeping my setup clean (without extra stuff I don't
really need or understand).

## LSP

TODO

## Formatting

I went with [formatter.nvim](https://github.com/mhartington/formatter.nvim) as
it's easy to configure and helps keep the same workflow with different file
types as I only have to memorize a single keymap for that.
Here are the formatters I use and which should be installed along with it:

- [stylua](https://github.com/johnnymorganz/stylua) for Lua
- [black](https://github.com/psf/black) for Python
- [shfmt](https://github.com/mvdan/sh) for Shell scripts
- For Golang I'm relying on three formatters to the job:
  - [gofmt](https://pkg.go.dev/cmd/gofmt) which does the main formatting, duh...
  - [goimports](https://pkg.go.dev/golang.org/x/tools/cmd/goimports) which sorts
    and groups imports
  - [golines](https://github.com/segmentio/golines) which will format lenghty
    lines for me in a civilized manner