;; extends

;; Set higher priority for builtin constants to win over LSP semantic tokens
;; LSP semantic tokens have priority 125-127, so we need 128+
((nil) @constant.builtin
  (#set! priority 128))

((true) @constant.builtin
  (#set! priority 128))

((false) @constant.builtin
  (#set! priority 128))

((iota) @constant.builtin
  (#set! priority 128))
