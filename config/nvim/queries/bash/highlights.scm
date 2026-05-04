;; extends

((command
  name: (command_name (word) @_command)
  argument: [
    (raw_string)
    (string)
  ] @injection.background.awk)
  (#eq? @_command "awk")
  (#match? @injection.background.awk "^[\"']\\s*(BEGIN\\b|END\\b|/)|^[\"'][^\"']*(\\{|\\$[0-9])")
  (#offset! @injection.background.awk 0 1 0 -1)
  (#set! priority 80))

((command
  name: (command_name (word) @_command)
  argument: [
    (raw_string)
    (string)
  ] @injection.background.jq)
  (#any-of? @_command "jq" "yq")
  (#match? @injection.background.jq "^[\"']\\s*(\\.|\\[|\\{|if\\b|def\\b|reduce\\b|foreach\\b|map\\b|select\\b|keys\\b|length\\b|to_entries\\b|from_entries\\b|del\\b|with_entries\\b|paths\\b|sort\\b|group_by\\b|unique\\b|any\\b|all\\b)")
  (#offset! @injection.background.jq 0 1 0 -1)
  (#set! priority 80))
