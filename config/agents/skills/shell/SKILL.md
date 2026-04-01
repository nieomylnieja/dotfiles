---
name: shell
description: >
  Use this skill when you're working with shell scripts (bash, sh).
  Covers script structure, formatting (shfmt), linting (shellcheck),
  argument parsing, help messages, error handling, and security.
allowed-tools: Bash(shellcheck *) Bash(shfmt *)
---

# Shell Scripting

Best practices for writing robust, maintainable shell scripts.

See [references/sources.md](./references/sources.md)
for the research sources behind these conventions.

## Tooling

Always prefer project-defined checks over bare tool invocations.
Look for a `Makefile`, `justfile`, or similar —
run `make lint`, `make check`,
or equivalent targets if they exist.
If no project targets are defined,
fall back to the tools below directly.

**Formatting — [shfmt](https://github.com/mvdan/sh):**

```sh
shfmt -i 2 -ci -bn -sr -w script.sh
```

| Flag   | Effect                                                |
| :----- | :---------------------------------------------------- |
| `-i 2` | 2-space indentation                                   |
| `-ci`  | Indent case body within switch                        |
| `-bn`  | Binary operators (`&&`, `\|`) may start a line        |
| `-sr`  | Space after redirect operators (`> file` not `>file`) |
| `-w`   | Write in-place                                        |
| `-d`   | Diff mode (CI-friendly, non-zero if differs)          |

Run [shfmt](https://github.com/mvdan/sh)
before committing and after making changes.

**Linting — [shellcheck](https://www.shellcheck.net/):**

```sh
shellcheck script.sh
```

Fix all [shellcheck](https://www.shellcheck.net/) warnings.
Do not disable checks with `# shellcheck disable=`
unless there is a documented, unavoidable reason —
and always include the reason inline.

## Shebang

Always use `#!/usr/bin/env bash` — never `#!/bin/bash`.
This is required for cross-system compatibility
where bash may live somewhere else, e.g. for NixOS is `/nix/store/...`.

For POSIX-only scripts
(rare — only when targeting minimal systems like Alpine/BusyBox),
use `#!/bin/sh`.

## Standard Preamble

Every script starts with:

```bash
#!/usr/bin/env bash

set -euo pipefail
```

| Flag          | Effect                              |
| :------------ | :---------------------------------- |
| `-e`          | Exit immediately on command failure |
| `-u`          | Treat unset variables as errors     |
| `-o pipefail` | Pipe fails if any component fails   |

### Caveats with `set -e`

- Commands in `if` conditions, `&&`/`||` chains, and `!` prefix suppress `-e`.
- `(( i++ ))` when `i=0` evaluates to 0 (falsy) and triggers exit.
  Use `(( i += 1 ))` instead.
- `local var=$(cmd)` always returns 0, masking failures.
  **Split declaration and assignment:**

  ```bash
  local my_var
  my_var="$(my_func)"
  ```

## Script Structure

Order declarations in this sequence:

1. **Shebang + `set` flags**
2. **Constants** (`readonly` at top of file)
3. **Help message function** (`usage`)
4. **Utility functions** (`log`, `warn`, `fatal`, `usage`)
5. **Core functions** (the script's logic)
6. **`main` function** (argument parsing + orchestration)
7. **`main "$@"` invocation** (last line of the script)

All scripts with functions must have a `main` function.
The last line of the script is always `main "$@"`.

## Documentation via `--help`

**Do not document scripts via code comments.
Document scripts via `--help` output.**

Every script must support `-h` and `--help` flags.
The help message goes to **stdout** and exits 0.

### Help Message Format

Follow
[GNU CLI conventions](https://www.gnu.org/prep/standards/standards.html#Command_002dLine-Interfaces):

```text
Usage: progname [OPTION]... [ARG]...
Brief one-line description of what the program does.

Options:
  -f, --file FILE    input file to process
  -o, --output FILE  output file (default: stdout)
  -v, --verbose      increase verbosity
  -q, --quiet        suppress output
  -h, --help         display this help and exit

Exit status:
  0  success
  1  general error
  2  usage error (invalid arguments)
```

Rules:

- **`Usage:` line first** — shows invocation syntax
- **One-line description** — what the program does, not how
- **Options section** —
  short and long option on the same line, aligned
- **Option arguments in UPPER_CASE**
  (e.g., `FILE`, `DIR`, `COUNT`)
- **Two-space indent** for option descriptions
- **`-h, --help` is always last** in the options list
- **Exit status section** at the end
- Use `${0##*/}` for the program name
  (strips directory path)

### Implementation Pattern

Implement the help message as a heredoc in a `usage` function:

```bash
usage() {
  cat <<EOF
Usage: ${0##*/} [OPTION]... [FILE]...
Brief description.

Options:
  -o, --output FILE  output file (default: stdout)
  -v, --verbose      increase verbosity
  -h, --help         display this help and exit

Exit status:
  0  success
  1  general error
  2  usage error
EOF
}
```

## Argument Parsing

### Manual Parsing (Preferred — Supports Long Options)

Manual argument parsing supports both short and long options:

```bash
main() {
  local verbose=0
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --verbose)
        verbose=1
        shift
        ;;
      -o | --output)
        [[ $# -lt 2 ]] && fatal "--output requires an argument" 2
        output="$2"
        shift 2
        ;;
      --output=*)
        output="${1#*=}"
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        fatal "Unknown option: $1" 2
        ;;
      *)
        break
        ;;
    esac
  done

  # Remaining positional args in "$@"
}
```

Key rules:

- Always handle `--` (end of options)
- Always reject unknown options (`-*`)
- Support `--option=value` syntax
  for long options with arguments
- Use `fatal` for invalid usage (exit code 2)

### `getopts` (POSIX Builtin — Short Options Only)

Use only when long options are not needed:

```bash
while getopts ':hvo:' opt; do
  case "${opt}" in
    h) usage; exit 0 ;;
    v) verbose=1 ;;
    o) output="${OPTARG}" ;;
    :) fatal "Option -${OPTARG} requires an argument" 2 ;;
    ?) fatal "Unknown option: -${OPTARG}" 2 ;;
  esac
done
shift "$((OPTIND - 1))"
```

## Error Handling and Logging

Standard logging functions to include in every script:

```bash
readonly PROG="${0##*/}"

log()  { echo "${PROG}: $*" >&2; }
warn() { echo "${PROG}: WARNING: $*" >&2; }
fatal()  { echo "${PROG}: ERROR: $*" >&2; exit "${2:-1}"; }
```

- All log output goes to **stderr**
- Prefix with program name for identifiability
- `fatal` accepts an optional second argument for exit code:
  `fatal "invalid arguments" 2`

## Exit Codes

| Code  | Meaning                                          |
| :---- | :----------------------------------------------- |
| 0     | Success                                          |
| 1     | General error                                    |
| 2     | Usage error (invalid arguments)                  |
| 126   | Command found but not executable                 |
| 127   | Command not found                                |
| 128+N | Killed by signal N (130 = SIGINT, 143 = SIGTERM) |

Use 1 for operational errors, 2 for usage errors.

## Cleanup and Signal Handling

Use `trap ... EXIT` for cleanup —
it covers all exit paths including signals:

```bash
cleanup() {
  rm -f "${tmpfile:-}"
}
trap cleanup EXIT
```

Use single quotes in `trap` strings
unless you intentionally want early expansion
([SC2064](https://www.shellcheck.net/wiki/SC2064)).

For signal-specific handling:

```bash
trap 'echo "Interrupted" >&2; exit 130' INT
trap 'echo "Terminated" >&2; exit 143' TERM
```

## Temporary Files

Always use `mktemp` for temporary files and directories:

```bash
tmpfile="$(mktemp)" || exit 1
tmpdir="$(mktemp -d)" || exit 1
trap 'rm -rf "${tmpdir}"' EXIT
```

**Never** use hardcoded paths in `/tmp` —
symlink attack risk.

## Variable and Quoting Rules

- **Always quote** variable expansions:
  `"${var}"`, `"$@"`, `"$(cmd)"`
- **Always use braces**: `${var}` not `$var`
  (exception: `$1`, `$?`, `$#`, `$$`, `$!`, `$@`)
- **Use `local`** for all function variables
- **Declare constants** with `readonly`:

  ```bash
  readonly VERSION="1.0.0"
  readonly DEFAULT_PORT=8080
  ```

- **Use `[[ ]]`** not `[ ]` for conditionals
- **Use `(( ))` or `$(( ))`** for arithmetic —
  never `let`, `expr`, or `$[ ]`
- **Use `$(command)`** not backticks
- **Use `command -v`** not `which`

## Arrays

Use arrays for argument lists —
never store args in strings.
Quote array expansions: `"${array[@]}"`.
Use `"$@"` to pass through all arguments.

```bash
local -a args=()
args+=("--flag")
args+=("--output" "${output}")
some_command "${args[@]}"
```

## Naming Conventions

| Element      | Convention                               | Example                     |
| :----------- | :--------------------------------------- | :-------------------------- |
| Functions    | `lower_snake_case`                       | `parse_args`, `run_build`   |
| Variables    | `lower_snake_case`                       | `input_file`, `retry_count` |
| Constants    | `UPPER_SNAKE_CASE`                       | `VERSION`, `DEFAULT_PORT`   |
| Script files | `lower-kebab-case` or `lower_snake_case` | `run-tests.sh`              |

## Common Anti-Patterns

**1. Parsing `ls` output:**

```bash
# WRONG:
for f in $(ls *.txt); do ...

# RIGHT:
for f in ./*.txt; do ...
```

**2. Unquoted variables in `rm`:**

```bash
# DANGEROUS — if ${dir} is empty, this deletes /:
rm -rf "${dir}/"

# SAFE — check first:
[[ -n "${dir}" ]] && rm -rf "${dir}"
```

**3. `cd` without error handling:**

```bash
# WRONG:
cd some/dir

# RIGHT:
cd some/dir || fatal "cannot cd to some/dir"
```

**4. `A && B || C` as if-then-else:**

```bash
# WRONG — C runs if B fails too:
do_thing && echo "ok" || echo "fail"

# RIGHT:
if do_thing; then
  echo "ok"
else
  echo "fail"
fi
```

**5. Reading lines with `for`:**

```bash
# WRONG — word splitting breaks lines:
for line in $(cat file); do ...

# RIGHT:
while IFS= read -r line; do
  ...
done < file
```

**6. Using `eval`:**

Never use `eval`.
Use arrays, `declare -n` (namerefs),
or indirect expansion `${!var}` instead.

**7. Useless `echo` wrapping:**

```bash
# WRONG:
result="$(echo "$(some_command)")"

# RIGHT:
result="$(some_command)"
```

**8. Glob expansion without prefix:**

```bash
# WRONG — filenames starting with - interpreted as flags:
rm *.tmp

# RIGHT:
rm ./*.tmp
# or:
rm -- *.tmp
```

## Security

- **Quote everything** —
  unquoted variables are the #1 source of bugs
- **Never use `eval`** — code injection vector
- **Use `--`** to terminate option parsing
  before user input: `rm -- "${user_input}"`
- **Set `PATH` explicitly** in scripts that run as root:
  `PATH=/usr/bin:/bin`
- **Use `mktemp`** for all temporary files
- **Set `umask 077`** before creating sensitive files
- **Never use SUID/SGID** on shell scripts
- **Validate external input** before passing to commands

## Complete Script Template

A complete example combining all conventions above:

```bash
#!/usr/bin/env bash
set -euo pipefail

readonly PROG="${0##*/}"
readonly VERSION="0.1.0"

usage() {
  cat <<EOF
Usage: ${PROG} [OPTION]... [FILE]...
Brief description of what this script does.

Options:
  -o, --output FILE  write output to FILE (default: stdout)
  -v, --verbose      increase verbosity
  -h, --help         display this help and exit
      --version      output version information and exit

Exit status:
  0  success
  1  general error
  2  usage error
EOF
}

log()  { echo "${PROG}: $*" >&2; }
warn() { echo "${PROG}: WARNING: $*" >&2; }
fatal()  { echo "${PROG}: ERROR: $*" >&2; exit "${2:-1}"; }

process() {
  local file="$1"
  log "Processing ${file}"
  # ...
}

main() {
  local verbose=0
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help) usage; exit 0 ;;
      --version) echo "${PROG} ${VERSION}"; exit 0 ;;
      -v | --verbose) verbose=1; shift ;;
      -o | --output)
        [[ $# -lt 2 ]] && fatal "--output requires an argument" 2
        output="$2"
        shift 2
        ;;
      --output=*)
        output="${1#*=}"
        shift
        ;;
      --) shift; break ;;
      -*) fatal "Unknown option: $1" 2 ;;
      *) break ;;
    esac
  done

  [[ $# -eq 0 ]] && fatal "no input files specified" 2

  for file in "$@"; do
    process "${file}"
  done
}

main "$@"
```
