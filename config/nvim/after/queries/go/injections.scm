;; extends

; Source: https://github.com/ray-x/go.nvim/blob/master/queries/go/injections.scm

;; ---
;; SQL injections
;; ---

; Pattern-based SQL injection (SELECT, INSERT, UPDATE, DELETE)
([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
 ] @injection.content
  (#match? @injection.content "(SELECT|select|INSERT|insert|UPDATE|update|DELETE|delete).+(FROM|from|INTO|into|VALUES|values|SET|set).*(WHERE|where|GROUP BY|group by)?")
(#set! injection.language "sql"))

; Comment-based SQL injection (-- sql or SQL keywords)
([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
 ] @injection.content
 (#contains? @injection.content "-- sql" "--sql"
   "ADD CONSTRAINT" "ALTER TABLE" "ALTER COLUMN"
   "DATABASE" "FOREIGN KEY" "GROUP BY" "HAVING" "CREATE INDEX" "INSERT INTO"
   "NOT NULL" "PRIMARY KEY" "UPDATE SET" "TRUNCATE TABLE" "LEFT JOIN"
   "add constraint" "alter table" "alter column"
   "database" "foreign key" "group by" "having" "create index" "insert into"
   "not null" "primary key" "update set" "truncate table" "left join")
 (#set! injection.language "sql"))


;; ---
;; JSON injections
;; ---

; jsonStr := `{"foo": "bar"}`
((const_spec
    name: (identifier) @_const
    value: (expression_list (raw_string_literal) @json))
  (#lua-match? @_const ".*[J|j]son.*"))

((short_var_declaration
    left: (expression_list (identifier) @_var)
    right: (expression_list (raw_string_literal) @json))
  (#lua-match? @_var ".*[J|j]son.*")
  (#offset! @json 0 1 0 -1))

; Variable name-based JSON injection (e.g., jsonStr := `{...}`)
(const_spec
  name: (identifier)
  value: (expression_list
	  (raw_string_literal
	    (raw_string_literal_content) @injection.content
        (#lua-match? @injection.content "^[\n|\t| ]*\{.*\}[\n|\t| ]*$")
        (#set! injection.language "json")
	  )
  )
)

(short_var_declaration
  left: (expression_list (identifier))
  right: (expression_list
    (raw_string_literal
      (raw_string_literal_content) @injection.content
      (#lua-match? @injection.content "^[\n|\t| ]*\{.*\}[\n|\t| ]*$")
      (#set! injection.language "json")
    )
  )
)

(var_spec
  name: (identifier)
  value: (expression_list
    (raw_string_literal
      (raw_string_literal_content) @injection.content
      (#lua-match? @injection.content "^[\n|\t| ]*\{.*\}[\n|\t| ]*$")
      (#set! injection.language "json")
    )
  )
)


;; ---
;; YAML injections
;; ---

; Pattern-based YAML injection (common YAML structures)
([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
 ] @injection.content
  (#match? @injection.content "(^|\\n)[a-zA-Z0-9_-]+:\\s*(\\n|\\||>|\\[|\\{|[^\\n]+\\n)")
(#set! injection.language "yaml"))

; Comment-based YAML injection (-- yaml or common YAML keywords)
([
  (interpreted_string_literal_content)
  (raw_string_literal_content)
 ] @injection.content
 (#contains? @injection.content "-- yaml" "--yaml" "---"
   "apiVersion:" "kind:" "metadata:" "spec:" "template:"
   "containers:" "image:" "ports:" "env:" "volumes:")
 (#set! injection.language "yaml"))

; Variable name-based YAML injection (e.g., yamlStr := `key: value`)
(const_spec
  name: (identifier) @_const
  value: (expression_list
    (raw_string_literal
      (raw_string_literal_content) @injection.content
    )
  )
  (#lua-match? @_const ".*[Y|y]aml.*")
  (#set! injection.language "yaml")
)

(short_var_declaration
  left: (expression_list (identifier) @_var)
  right: (expression_list
    (raw_string_literal
      (raw_string_literal_content) @injection.content
    )
  )
  (#lua-match? @_var ".*[Y|y]aml.*")
  (#set! injection.language "yaml")
)

(var_spec
  name: (identifier) @_var
  value: (expression_list
    (raw_string_literal
      (raw_string_literal_content) @injection.content
    )
  )
  (#lua-match? @_var ".*[Y|y]aml.*")
  (#set! injection.language "yaml")
)
