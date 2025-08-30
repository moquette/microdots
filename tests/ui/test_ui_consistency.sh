#!/usr/bin/env bash
#
# UI Consistency Test Suite
# Tests the unified UI library across all dotfiles commands
#
# This test suite validates that all commands:
# 1. Use UI functions instead of raw echo statements
# 2. Have consistent symbol usage
# 3. Maintain proper formatting without extra spaces
# 4. Follow proper header hierarchy
# 5. Route errors to stderr correctly
#

set -e

# Get test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_ROOT="$(dirname "$TESTS_DIR")"
CORE_DIR="$DOTFILES_ROOT/core"

# Source test framework
source "$TESTS_DIR/test_framework.sh"

# Source UI library for reference
source "$CORE_DIR/lib/ui.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "Running: $test_name"
    
    if "$test_function"; then
        echo " PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo " FAIL: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
}

# Test 1: No raw echo statements in commands
test_no_raw_echo_statements() {
    local violations=0
    
    # Check all command files
    for cmd in "$CORE_DIR/commands"/*; do
        [ -f "$cmd" ] || continue
        
        # Look for raw echo statements (excluding heredocs and specific exceptions)
        # We allow: echo in heredocs, echo "", echo for return values, echo with variables only
        if grep -n 'echo [^$"].*[:!ó]' "$cmd" 2>/dev/null; then
            echo "ERROR: Found raw echo with UI symbols in $(basename "$cmd")"
            violations=$((violations + 1))
        fi
        
        # Check for hardcoded success/error patterns
        if grep -n 'echo.*"\|echo.*"\|echo.*"!"\|echo.*":"' "$cmd" 2>/dev/null; then
            echo "ERROR: Found hardcoded UI symbols in $(basename "$cmd")"
            violations=$((violations + 1))
        fi
    done
    
    # Also check the main router
    if grep -n 'echo [^$"].*[:!ó]' "$CORE_DIR/dots" 2>/dev/null; then
        echo "ERROR: Found raw echo with UI symbols in dots router"
        violations=$((violations + 1))
    fi
    
    return $violations
}

# Test 2: Consistent symbol usage across commands
test_consistent_symbols() {
    local issues=0
    
    # Expected symbols from ui.sh
    local expected_check=""
    local expected_cross=""
    local expected_warn="!"
    local expected_info=":"
    local expected_progress="ó"
    
    # Check all commands for consistent symbol usage
    for cmd in "$CORE_DIR/commands"/* "$CORE_DIR/dots"; do
        [ -f "$cmd" ] || continue
        
        # Look for wrong symbols
        if grep -q '[L ]' "$cmd" 2>/dev/null; then
            echo "ERROR: Found inconsistent symbols in $(basename "$cmd")"
            grep -n '[L ]' "$cmd" 2>/dev/null | head -3
            issues=$((issues + 1))
        fi
        
        # Look for ASCII fallback usage in wrong context
        if grep -q '\[OK\]\|\[FAIL\]\|\[!\]' "$cmd" 2>/dev/null; then
            local context=$(grep -n '\[OK\]\|\[FAIL\]\|\[!\]' "$cmd" 2>/dev/null | head -1)
            # Only flag if it's not in a comment or fallback definition
            if ! echo "$context" | grep -q '^[[:space:]]*#'; then
                echo "ERROR: Found ASCII symbols instead of Unicode in $(basename "$cmd")"
                echo "  $context"
                issues=$((issues + 1))
            fi
        fi
    done
    
    return $issues
}

# Test 3: No extra spaces in UI function calls
test_no_extra_spaces_in_messages() {
    local violations=0
    
    for cmd in "$CORE_DIR/commands"/* "$CORE_DIR/dots"; do
        [ -f "$cmd" ] || continue
        
        # Look for UI functions with leading spaces in the message
        # Pattern: success "  message" or error "  message" etc.
        if grep -n -E '(success|error|warning|info|progress)\s+"[[:space:]]{2,}' "$cmd" 2>/dev/null; then
            echo "ERROR: Found UI function calls with extra leading spaces in $(basename "$cmd"):"
            grep -n -E '(success|error|warning|info|progress)\s+"[[:space:]]{2,}' "$cmd" 2>/dev/null
            violations=$((violations + 1))
        fi
        
        # Look for trailing spaces in messages (less common but still wrong)
        if grep -n -E '(success|error|warning|info|progress)\s+".*[[:space:]]+"\s*$' "$cmd" 2>/dev/null; then
            echo "ERROR: Found UI function calls with trailing spaces in $(basename "$cmd"):"
            grep -n -E '(success|error|warning|info|progress)\s+".*[[:space:]]+"\s*$' "$cmd" 2>/dev/null
            violations=$((violations + 1))
        fi
    done
    
    return $violations
}

# Test 4: Proper header hierarchy usage
test_header_hierarchy() {
    local violations=0
    
    for cmd in "$CORE_DIR/commands"/*; do
        [ -f "$cmd" ] || continue
        
        # Count header vs subheader usage
        local header_count=$(grep -c '^[[:space:]]*header[[:space:]]' "$cmd" 2>/dev/null || echo "0")
        local subheader_count=$(grep -c '^[[:space:]]*subheader[[:space:]]' "$cmd" 2>/dev/null || echo "0")
        
        # Each command should typically have 1 main header and multiple subheaders
        if [ "$header_count" -gt 2 ]; then
            echo "WARNING: $(basename "$cmd") has $header_count main headers (may be too many)"
            # This is a warning, not a failure
        fi
        
        # Check for proper usage - no header calls with empty strings
        if grep -n 'header[[:space:]]*""' "$cmd" 2>/dev/null; then
            echo "ERROR: Found empty header call in $(basename "$cmd")"
            violations=$((violations + 1))
        fi
        
        if grep -n 'subheader[[:space:]]*""' "$cmd" 2>/dev/null; then
            echo "ERROR: Found empty subheader call in $(basename "$cmd")"
            violations=$((violations + 1))
        fi
    done
    
    return $violations
}

# Test 5: Error messages go to stderr
test_error_stderr_routing() {
    # This test runs actual commands and checks that errors go to stderr
    local temp_stdout=$(mktemp)
    local temp_stderr=$(mktemp)
    local violations=0
    
    # Test invalid command (should produce error to stderr)
    "$CORE_DIR/dots" invalid_command >"$temp_stdout" 2>"$temp_stderr" || true
    
    # Check that error went to stderr, not stdout
    if ! grep -q "Unknown command" "$temp_stderr"; then
        echo "ERROR: dots router error message not found in stderr"
        violations=$((violations + 1))
    fi
    
    if grep -q "Unknown command" "$temp_stdout"; then
        echo "ERROR: dots router error message found in stdout (should be stderr)"
        violations=$((violations + 1))
    fi
    
    # Test help command (should go to stdout)
    "$CORE_DIR/dots" help >"$temp_stdout" 2>"$temp_stderr"
    
    if ! grep -q "Usage:" "$temp_stdout"; then
        echo "ERROR: dots help output not found in stdout"
        violations=$((violations + 1))
    fi
    
    # Clean up temp files
    rm -f "$temp_stdout" "$temp_stderr"
    
    return $violations
}

# Test 6: UI library function export validation
test_ui_function_exports() {
    local missing_functions=0
    
    # Expected exported functions from ui.sh
    local expected_functions=(
        "header" "subheader" "info" "success" "warning" "error" 
        "progress" "prompt" "list_item" "indent" "key_value" 
        "separator" "blank" "status" "show_progress" "summary" 
        "spinner" "debug" "table_header" "table_row"
    )
    
    # Source the UI library and check each function exists
    source "$CORE_DIR/lib/ui.sh"
    
    for func in "${expected_functions[@]}"; do
        if ! declare -f "$func" >/dev/null 2>&1; then
            echo "ERROR: Function '$func' not found or not exported"
            missing_functions=$((missing_functions + 1))
        fi
    done
    
    return $missing_functions
}

# Test 7: Color and terminal capability handling
test_color_handling() {
    local issues=0
    
    # Test with colors enabled (simulated)
    (
        export TERM="xterm-256color"
        source "$CORE_DIR/lib/ui.sh"
        
        # Check that color variables are set
        if [ -z "$GREEN" ] || [ -z "$RED" ] || [ -z "$BOLD" ]; then
            echo "ERROR: Color variables not set with color terminal"
            exit 1
        fi
        
        # Check that Unicode symbols are used
        if [ "$CHECK" != "" ] || [ "$CROSS" != "" ]; then
            echo "ERROR: Unicode symbols not set with modern terminal"
            exit 1
        fi
    ) || issues=$((issues + 1))
    
    # Test with colors disabled (simulated)
    (
        unset TERM
        export TERM=""
        # Redirect stdout to /dev/null to simulate non-tty
        exec 1>/dev/null
        source "$CORE_DIR/lib/ui.sh"
        
        # Check that color variables are empty
        if [ -n "$GREEN" ] || [ -n "$RED" ] || [ -n "$BOLD" ]; then
            echo "ERROR: Color variables set without color terminal" >&2
            exit 1
        fi
    ) || issues=$((issues + 1))
    
    return $issues
}

# Test 8: Command output format consistency
test_command_output_format() {
    local temp_output=$(mktemp)
    local violations=0
    
    # Test each command's help output for consistency
    for cmd_name in bootstrap install relink status maintenance; do
        if [ -f "$CORE_DIR/commands/$cmd_name" ]; then
            # Most commands support --help
            if "$CORE_DIR/commands/$cmd_name" --help >"$temp_output" 2>/dev/null || true; then
                # Check for proper formatting in help output
                if grep -q "^Usage:" "$temp_output" || grep -q "^dots $cmd_name" "$temp_output"; then
                    # Good - has usage section
                    continue
                fi
                
                # Check for proper UI formatting (headers should be bold in terminal)
                if ! grep -q "^[A-Z]" "$temp_output"; then
                    echo "WARNING: $cmd_name help output may lack proper section headers"
                fi
            fi
        fi
    done
    
    # Test status command specifically (should have structured output)
    "$CORE_DIR/commands/status" >"$temp_output" 2>/dev/null || true
    
    # Check for expected sections
    if ! grep -q "Core Configuration" "$temp_output"; then
        echo "ERROR: status command missing expected 'Core Configuration' section"
        violations=$((violations + 1))
    fi
    
    if ! grep -q "Local Configuration" "$temp_output"; then
        echo "ERROR: status command missing expected 'Local Configuration' section"
        violations=$((violations + 1))
    fi
    
    rm -f "$temp_output"
    return $violations
}

# Test 9: Validation of actual command output patterns
test_actual_command_output() {
    local temp_dir=$(mktemp -d)
    local temp_output="$temp_dir/output"
    local temp_stderr="$temp_dir/stderr"
    local violations=0
    
    # Test relink with dry-run (safest to test)
    "$CORE_DIR/commands/relink" --dry-run >"$temp_output" 2>"$temp_stderr" || true
    
    # Check for proper symbols in output
    local found_symbols=0
    if grep -q "\|:\|!" "$temp_output"; then
        found_symbols=1
    fi
    
    if [ $found_symbols -eq 0 ]; then
        # Maybe running in fallback mode, check for ASCII symbols
        if ! grep -q "\[OK\]\|>\|!" "$temp_output"; then
            echo "ERROR: relink command output missing expected UI symbols (Unicode or ASCII)"
            violations=$((violations + 1))
        fi
    fi
    
    # Check that output has expected structure
    if ! grep -q "Dotfiles Relink" "$temp_output"; then
        echo "ERROR: relink command missing expected header"
        violations=$((violations + 1))
    fi
    
    # Test status command output
    "$CORE_DIR/commands/status" >"$temp_output" 2>"$temp_stderr" || true
    
    # Should have structured key-value output
    if ! grep -q "’" "$temp_output" && ! grep -q "->" "$temp_output"; then
        echo "ERROR: status command missing expected key-value arrows"
        violations=$((violations + 1))
    fi
    
    rm -rf "$temp_dir"
    return $violations
}

# Test 10: Source code analysis for common mistakes
test_common_coding_mistakes() {
    local violations=0
    
    for cmd in "$CORE_DIR/commands"/* "$CORE_DIR/dots"; do
        [ -f "$cmd" ] || continue
        local cmd_name=$(basename "$cmd")
        
        # Check for mixed UI function usage
        local has_success=$(grep -c 'success[[:space:]]' "$cmd" 2>/dev/null || echo "0")
        local has_raw_ok=$(grep -c 'echo.*OK\|echo.*' "$cmd" 2>/dev/null || echo "0")
        
        if [ "$has_success" -gt 0 ] && [ "$has_raw_ok" -gt 0 ]; then
            echo "ERROR: $cmd_name mixes success() function with raw echo statements"
            violations=$((violations + 1))
        fi
        
        # Check for inconsistent error handling
        local has_error_func=$(grep -c 'error[[:space:]]' "$cmd" 2>/dev/null || echo "0")
        local has_raw_error=$(grep -c 'echo.*ERROR\|echo.*' "$cmd" 2>/dev/null || echo "0")
        
        if [ "$has_error_func" -gt 0 ] && [ "$has_raw_error" -gt 0 ]; then
            echo "ERROR: $cmd_name mixes error() function with raw echo statements"
            violations=$((violations + 1))
        fi
        
        # Check for hardcoded color codes (should use UI library variables)
        if grep -q '\033\[\|\\e\[' "$cmd" 2>/dev/null; then
            echo "ERROR: $cmd_name contains hardcoded ANSI color codes"
            violations=$((violations + 1))
        fi
        
        # Check for missing UI library source
        if [ "$cmd_name" != "dots" ]; then  # Skip main router
            if ! grep -q 'source.*ui\.sh\|source.*common\.sh' "$cmd" 2>/dev/null; then
                echo "ERROR: $cmd_name doesn't source UI library"
                violations=$((violations + 1))
            fi
        fi
    done
    
    return $violations
}

# Main test runner
main() {
    echo ">ê UI Consistency Test Suite"
    echo "============================================================"
    echo ""
    
    # Run all tests
    run_test "No raw echo statements with UI symbols" test_no_raw_echo_statements
    run_test "Consistent symbol usage" test_consistent_symbols
    run_test "No extra spaces in UI messages" test_no_extra_spaces_in_messages
    run_test "Proper header hierarchy" test_header_hierarchy
    run_test "Error messages routed to stderr" test_error_stderr_routing
    run_test "UI library function exports" test_ui_function_exports
    run_test "Color and terminal handling" test_color_handling
    run_test "Command output format consistency" test_command_output_format
    run_test "Actual command output validation" test_actual_command_output
    run_test "Common coding mistakes" test_common_coding_mistakes
    
    # Final summary
    echo "============================================================"
    echo "UI Consistency Test Results:"
    echo "  Total tests:  $TESTS_RUN"
    echo "  Passed:       $TESTS_PASSED"
    echo "  Failed:       $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo "L UI consistency tests FAILED"
        echo ""
        echo "Common fixes:"
        echo "  " Replace 'echo \" message\"' with 'success \"message\"'"
        echo "  " Replace 'echo \" error\"' with 'error \"error\"'"
        echo "  " Replace 'echo \"! warning\"' with 'warning \"warning\"'"
        echo "  " Replace 'echo \": info\"' with 'info \"info\"'"
        echo "  " Remove extra spaces: success \"  message\" ’ success \"message\""
        echo "  " Use 'header' once per command, 'subheader' for sections"
        exit 1
    else
        echo " All UI consistency tests PASSED"
        exit 0
    fi
}

# Run tests
main "$@"