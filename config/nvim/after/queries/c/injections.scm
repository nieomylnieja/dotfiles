;; extends

; Enable assembly highlighting in inline asm blocks
; GCC-style: __asm__("mov %0, %1" : ...)
(gnu_asm_expression
  assembly_code: (string_literal
    (string_content) @injection.content)
  (#set! injection.language "asm"))

; GCC-style with concatenated strings
(gnu_asm_expression
  assembly_code: (concatenated_string
    (string_literal
      (string_content) @injection.content))
  (#set! injection.language "asm"))
