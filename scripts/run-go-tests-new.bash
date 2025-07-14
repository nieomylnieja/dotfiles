#!/bin/bash

# This script uses fzf to find and run Go tests interactively.
# It lists all Test and Benchmark functions in the current directory and its subdirectories,
# allows you to select them using fzf, and then runs the selected tests.

# Use speedups like ripgrep and fd to find test functions.
# Run the tests with gotestsum.

set -euo pipefail

# --- Configuration ---
GO_TEST_FLAGS="-v"  # Default flags for go test

# --- Functions ---

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

check_dependencies() {
    local missing_deps=()
    
    if ! command -v fzf &>/dev/null; then
        missing_deps+=("fzf")
    fi
    
    if ! command -v go &>/dev/null; then
        missing_deps+=("go")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error_exit "Missing required dependencies: ${missing_deps[*]}"
    fi
}

find_test_files() {
    # Use fd if available (faster), otherwise fall back to find
    if command -v fd &>/dev/null; then
        fd -e go -x echo {} \; | grep '_test\.go$'
    else
        find . -name "*_test.go" -type f
    fi
}

extract_test_functions() {
    local test_file="$1"
    local package_path
    package_path=$(dirname "$test_file" | sed 's|^\./||')
    
    # Use ripgrep if available (faster), otherwise fall back to grep
    if command -v rg &>/dev/null; then
        rg -o '^func (Test|Benchmark)[A-Z][a-zA-Z0-9_]*' "$test_file" 2>/dev/null | \
            sed 's/^func //' | \
            awk -v pkg="$package_path" '{print pkg "/" $0}' || true
    else
        grep -o '^func \(Test\|Benchmark\)[A-Z][a-zA-Z0-9_]*' "$test_file" 2>/dev/null | \
            sed 's/^func //' | \
            awk -v pkg="$package_path" '{print pkg "/" $0}' || true
    fi
}

# --- Main Script ---

echo "🔍 Scanning for Go test functions..."

check_dependencies

# Check if gotestsum is available
if command -v gotestsum &>/dev/null; then
    TEST_COMMAND="gotestsum --"
    echo "✓ Using gotestsum for running tests"
else
    TEST_COMMAND="go test"
    echo "⚠ gotestsum not found, falling back to 'go test'"
fi

# Find all test files
TEST_FILES=$(find_test_files)

if [ -z "$TEST_FILES" ]; then
    echo "❌ No Go test files found in the current directory or subdirectories"
    exit 0
fi

echo "📋 Found $(echo "$TEST_FILES" | wc -l) test file(s)"

# Create temporary file for test list
TEMP_TEST_LIST=$(mktemp)
trap 'rm -f "$TEMP_TEST_LIST"' EXIT

# Extract test functions from all test files
while IFS= read -r test_file; do
    if [ -f "$test_file" ]; then
        extract_test_functions "$test_file" >> "$TEMP_TEST_LIST"
    fi
done <<< "$TEST_FILES"

# Check if any test functions were found
if [ ! -s "$TEMP_TEST_LIST" ]; then
    echo "❌ No test functions found"
    exit 0
fi

echo "🎯 Found $(wc -l < "$TEMP_TEST_LIST") test function(s)"
echo ""
echo "📝 Select tests to run:"
echo "   • Tab: multi-select"
echo "   • Ctrl-A: select all" 
echo "   • Enter: run selected tests"
echo ""

# Use fzf for interactive test selection
SELECTED_TESTS=$(fzf \
    --multi \
    --bind 'ctrl-a:select-all' \
    --prompt="Select tests > " \
    --preview-window="right:50%" \
    --preview="echo 'Package: {1}' && echo 'Test: {2}' | sed 's|.*/||'" \
    --header="Tab=multi-select, Ctrl-A=select-all, Enter=run" \
    < "$TEMP_TEST_LIST")

if [ -z "$SELECTED_TESTS" ]; then
    echo "❌ No tests selected"
    exit 0
fi

# Group tests by package
declare -A TESTS_BY_PACKAGE

while IFS= read -r line; do
    PKG_PATH=$(dirname "$line")
    TEST_NAME=$(basename "$line")
    
    if [ -z "${TESTS_BY_PACKAGE[$PKG_PATH]:-}" ]; then
        TESTS_BY_PACKAGE["$PKG_PATH"]="$TEST_NAME"
    else
        TESTS_BY_PACKAGE["$PKG_PATH"]="${TESTS_BY_PACKAGE[$PKG_PATH]}|$TEST_NAME"
    fi
done <<< "$SELECTED_TESTS"

echo ""
echo "🚀 Running selected tests..."
echo ""

# Run tests for each package
FAILED_PACKAGES=()
TOTAL_PACKAGES=${#TESTS_BY_PACKAGE[@]}
CURRENT_PACKAGE=0

for PKG_PATH in "${!TESTS_BY_PACKAGE[@]}"; do
    ((CURRENT_PACKAGE++))
    
    TEST_REGEX="${TESTS_BY_PACKAGE[$PKG_PATH]}"
    
    echo "📦 [$CURRENT_PACKAGE/$TOTAL_PACKAGES] Running tests in package: $PKG_PATH"
    echo "   Tests: $(echo "$TEST_REGEX" | tr '|' ' ')"
    
    # Convert to proper Go module path if needed
    GO_PKG_PATH="$PKG_PATH"
    if [ "$PKG_PATH" = "." ]; then
        GO_PKG_PATH="."
    else
        GO_PKG_PATH="./$PKG_PATH"
    fi
    
    # Run the tests
    if $TEST_COMMAND -run "^($TEST_REGEX)$" $GO_TEST_FLAGS "$GO_PKG_PATH"; then
        echo "✅ Tests passed in $PKG_PATH"
    else
        echo "❌ Tests failed in $PKG_PATH"
        FAILED_PACKAGES+=("$PKG_PATH")
    fi
    echo ""
done

# Summary
echo "🏁 Test execution completed"
echo ""

if [ ${#FAILED_PACKAGES[@]} -eq 0 ]; then
    echo "🎉 All tests passed!"
else
    echo "💥 Failed packages:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo "   • $pkg"
    done
    exit 1
fi
