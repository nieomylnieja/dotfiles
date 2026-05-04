((comment) @injection.content
  (#set! injection.language "comment"))

((regex) @injection.content
  (#set! injection.language "regex"))

((command
  name: (command_name (word) @_command)
  argument: [
    (raw_string)
    (string)
  ] @injection.content)
  (#eq? @_command "awk")
  (#match? @injection.content "^[\"']\\s*(BEGIN\\b|END\\b|/)|^[\"'][^\"']*(\\{|\\$[0-9])")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "awk"))

((command
  name: (command_name (word) @_command)
  argument: [
    (raw_string)
    (string)
  ] @injection.content)
  (#any-of? @_command "jq" "yq")
  (#match? @injection.content "^[\"']\\s*(\\.|\\[|\\{|if\\b|def\\b|reduce\\b|foreach\\b|map\\b|select\\b|keys\\b|length\\b|to_entries\\b|from_entries\\b|del\\b|with_entries\\b|paths\\b|sort\\b|group_by\\b|unique\\b|any\\b|all\\b)")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "jq"))

; printf 'format'
((command
  name: (command_name) @_command
  .
  argument: [
    (string) @injection.content
    (concatenation
      (string) @injection.content)
    (raw_string) @injection.content
    (concatenation
      (raw_string) @injection.content)
  ])
  (#eq? @_command "printf")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "printf"))

; printf -v var 'format'
((command
  name: (command_name) @_command
  argument: (word) @_arg
  .
  (_)
  .
  argument: [
    (string) @injection.content
    (concatenation
      (string) @injection.content)
    (raw_string) @injection.content
    (concatenation
      (raw_string) @injection.content)
  ])
  (#eq? @_command "printf")
  (#eq? @_arg "-v")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "printf"))

; printf -- 'format'
((command
  name: (command_name) @_command
  argument: (word) @_arg
  .
  argument: [
    (string) @injection.content
    (concatenation
      (string) @injection.content)
    (raw_string) @injection.content
    (concatenation
      (raw_string) @injection.content)
  ])
  (#eq? @_command "printf")
  (#eq? @_arg "--")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "printf"))

((command
  name: (command_name) @_command
  .
  argument: [
    (string)
    (raw_string)
  ] @injection.content)
  (#eq? @_command "bind")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.language "readline"))

((command
  name: (command_name) @_command
  .
  argument: [
    (string)
    (raw_string)
  ] @injection.content)
  (#eq? @_command "trap")
  (#offset! @injection.content 0 1 0 -1)
  (#set! injection.include-children)
  (#set! injection.self))
