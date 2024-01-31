-- specify browser to open preview page
-- default: ''
vim.g.mkdp_browser = os.getenv "BROWSER"

-- options for markdown render
-- mkit: markdown-it options for render
-- katex: katex options for math
-- uml: markdown-it-plantuml options
-- maid: mermaid options
-- disable_sync_scroll: if disable sync scroll, default 0
-- sync_scroll_type: 'middle', 'top' or 'relative', default value is 'middle'
--   middle: mean the cursor position alway show at the middle of the preview page
--   top: mean the vim top viewport alway show at the top of the preview page
--   relative: mean the cursor position alway show at the relative positon of the preview page
-- hide_yaml_meta: if hide yaml metadata, default is 1
-- sequence_diagrams: js-sequence-diagrams options
-- content_editable: if enable content editable for preview page, default: v:false
-- disable_filename: if disable filename header for preview page, default: 0
vim.g.mkdp_preview_options = {
  mkit = {},
  katex = {},
  uml = {
    -- TODO: Automate this `docker run -d -p 8091:8080 plantuml/plantuml-server:jetty`
    server = "http://localhost:8091",
  },
  maid = {},
  disable_sync_scroll = 0,
  hide_yaml_meta = 1,
  sync_scroll_type = "relative",
  sequence_diagrams = {},
  flowchart_diagrams = {},
  content_editable = false,
  disable_filename = 0,
}

-- recognized filetypes
-- these filetypes will have MarkdownPreview... commands
vim.g.mkdp_filetypes = { "markdown", "plantuml" }
