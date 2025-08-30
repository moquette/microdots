#!/usr/bin/env bash
#
# Command Integration UI Tests  
# Tests actual command output for UI consistency
#

set -e

# Get paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_ROOT="$(dirname "$TESTS_DIR")"
CORE_DIR="$DOTFILES_ROOT/core"

# Source test framework
source "$TESTS_DIR/test_framework.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "Testing: $test_name"
    
    if "$test_function"; then
        echo " PASS: $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo " FAIL: $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    echo ""
}

capture_command() {
    local temp_stdout=$(mktemp)
    local temp_stderr=$(mktemp)
    
    # Run command and capture both stdout and stderr
    "$@" >"$temp_stdout" 2>"$temp_stderr" || true
    
    # Return results
    echo "STDOUT:"
    cat "$temp_stdout"
    echo "STDERR:"
    cat "$temp_stderr"
    
    # Clean up
    rm -f "$temp_stdout" "$temp_stderr"
}

# Test 1: Help command output consistency
test_help_command_ui() {
    local violations=0
    local output=$(capture_command "$CORE_DIR/dots" help)
    
    # Should have consistent header format
    if ! echo "$output" | grep -q "dots - dotfiles management system"; then
        echo "ERROR: Help doesn't have proper title"
        violations=$((violations + 1))
    fi
    
    # Should have structured sections
    if ! echo "$output" | grep -q "Usage:"; then
        echo "ERROR: Help missing Usage section"
        violations=$((violations + 1))
    fi
    
    if ! echo "$output" | grep -q "Commands:"; then
        echo "ERROR: Help missing Commands section"
        violations=$((violations + 1))
    fi
    
    # Should not contain raw symbols (should use UI functions if any output functions used)
    if echo "$output" | grep -qE 'STDOUT:.*[!:].*[^(]'; then
        echo "ERROR: Help output contains raw UI symbols (should use functions)"
        violations=$((violations + 1))
    fi
    
    return $violations
}

# Test 2: Status command output structure
test_status_command_ui() {
    local violations=0
    local output=$(capture_command "$CORE_DIR/commands/status")
    
    # Should have main header with proper formatting
    if ! echo "$output" | grep -q "Dotfiles System Status"; then
        echo "ERROR: Status missing main header"
        violations=$((violations + 1))
    fi
    
    # Should have section headers (subheaders)
    local expected_sections=("Core Configuration" "Local Configuration" "Symlink Status" "Summary")
    for section in "${expected_sections[@]}"; do
        if ! echo "$output" | grep -q "$section"; then
            echo "ERROR: Status missing section: $section"
            violations=$((violations + 1))
        fi
    done
    
    # Should have key-value pairs with arrows
    if ! echo "$output" | grep -qE "’|->"; then
        echo "ERROR: Status missing key-value arrows"
        violations=$((violations + 1))
    fi
    
    # Should have proper UI symbols
    if echo "$output" | grep -qE 'STDOUT:.*[!:]'; then
        # Good - has UI symbols
        # Check for consistency - all should use same symbol set
        local has_unicode_check=$(echo "$output" | grep -c "" || echo "0")
        local has_ascii_check=$(echo "$output" | grep -c "\[OK\]" || echo "0")
        
        if [ "$has_unicode_check" -gt 0 ] && [ "$has_ascii_check" -gt 0 ]; then
            echo "ERROR: Status mixes Unicode and ASCII symbols"
            violations=$((violations + 1))
        fi
    fi
    
    return $violations
}

# Test 3: Relink dry-run output (safest to test)
test_relink_dry_run_ui() {
    local violations=0
    local output=$(capture_command "$CORE_DIR/commands/relink" --dry-run)
    
    # Should have main header
    if ! echo "$output" | grep -q "Dotfiles Relink"; then
        echo "ERROR: Relink missing main header"
        violations=$((violations + 1))
    fi
    
    # Should have validation section
    if ! echo "$output" | grep -q "Configuration Validation"; then
        echo "ERROR: Relink missing validation section"
        violations=$((violations + 1))
    fi
    
    # Should show dry-run indicators
    if ! echo "$output" | grep -q "dry-run"; then
        echo "ERROR: Relink dry-run not clearly indicated"
        violations=$((violations + 1))
    fi
    
    # Should have proper UI symbols for success/info
    if echo "$output" | grep -qE 'STDOUT:.*[:]'; then
        # Should not mix symbol types
        local has_unicode=$(echo "$output" | grep -cE "STDOUT:.*[:]" || echo "0")
        local has_ascii=$(echo "$output" | grep -cE "STDOUT:.*(\[OK\]|>)" || echo "0")
        
        if [ "$has_unicode" -gt 0 ] && [ "$has_ascii" -gt 0 ]; then
            echo "ERROR: Relink mixes Unicode and ASCII symbols"
            violations=$((violations + 1))
        fi
    fi
    
    # Should have summary section
    if ! echo "$output" | grep -qE "Dry-run complete|Would create"; then
        echo "ERROR: Relink missing dry-run summary"
        violations=$((violations + 1))
    fi
    
    return $violations
}

# Test 4: Invalid command error handling
test_error_command_ui() {
    local violations=0
    local output=$(capture_command "$CORE_DIR/dots" invalid_command_xyz)
    
    # Error should go to stderr
    if ! echo "$output" | grep -A 10 "STDERR:" | grep -q "Unknown command"; then
        echo "ERROR: Invalid command error not in stderr"
        violations=$((violations + 1))
    fi
    
    # Stdout should be empty or minimal
    local stdout_content=$(echo "$output" | sed -n '/STDOUT:/,/STDERR:/p' | head -n -1 | tail -n +2)
    if [ -n "$stdout_content" ] && [ "$stdout_content" != "" ]; then
        echo "ERROR: Invalid command produced stdout output: '$stdout_content'"
        violations=$((violations + 1))
    fi
    
    # Should have consistent error format
    if echo "$output" | grep -A 10 "STDERR:" | grep -qE '[L].*Unknown command'; then
        # Good - has error symbol
        return $violations
    elif echo "$output" | grep -A 10 "STDERR:" | grep -q "Unknown command"; then
        # Acceptable if no symbols but has error text
        return $violations
    else
        echo "ERROR: Invalid command error format inconsistent"
        violations=$((violations + 1))
    fi
    
    return $violations
}

# Test 5: Command help consistency across all commands
test_command_help_consistency() {
    local violations=0
    local commands=("bootstrap" "install" "relink" "status" "maintenance")
    
    for cmd in "${commands[@]}"; do
        if [ -f "$CORE_DIR/commands/$cmd" ]; then
            local help_output=$(capture_command "$CORE_DIR/commands/$cmd" --help 2>/dev/null || echo "NO_HELP")
            
            if [ "$help_output" = "NO_HELP" ]; then
                # Some commands might not support --help, skip
                continue
            fi
            
            # Check for consistent help format
            if echo "$help_output" | grep -q "STDOUT:" && ! echo "$help_output" | grep -A 20 "STDOUT:" | grep -qE "(Usage|Options)"; then
                echo "WARNING: $cmd help output may lack standard sections"
                # This is a warning, not an error
            fi
            
            # Check that help goes to stdout, not stderr
            if echo "$help_output" | grep -A 20 "STDERR:" | grep -qE "[Uu]sage|[Oo]ptions"; then
                echo "ERROR: $cmd help output goes to stderr instead of stdout"
                violations=$((violations + 1))
            fi
        fi
    done
    
    return $violations
}

# Test 6: UI symbol consistency across commands
test_cross_command_symbol_consistency() {
    local violations=0
    local temp_dir=$(mktemp -d)
    
    # Collect output from multiple safe commands
    "$CORE_DIR/commands/status" >"$temp_dir/status.out" 2>&1 || true
    "$CORE_DIR/commands/relink" --dry-run >"$temp_dir/relink.out" 2>&1 || true
    "$CORE_DIR/dots" help >"$temp_dir/help.out" 2>&1 || true
    
    # Analyze symbol usage across all outputs
    local total_unicode_symbols=0
    local total_ascii_symbols=0
    
    for file in "$temp_dir"/*.out; do
        [ -f "$file" ] || continue
        
        local unicode_count=$(grep -cE '[!:ó]' "$file" 2>/dev/null || echo "0")
        local ascii_count=$(grep -cE '\[OK\]|\[FAIL\]|\[!\]' "$file" 2>/dev/null || echo "0")
        
        total_unicode_symbols=$((total_unicode_symbols + unicode_count))
        total_ascii_symbols=$((total_ascii_symbols + ascii_count))
    done
    
    # If we have symbols, they should be consistent
    if [ "$total_unicode_symbols" -gt 0 ] && [ "$total_ascii_symbols" -gt 0 ]; then
        echo "ERROR: Commands use mixed Unicode ($total_unicode_symbols) and ASCII ($total_ascii_symbols) symbols"
        violations=$((violations + 1))
    fi
    
    rm -rf "$temp_dir"
    return $violations
}

# Test 7: Header hierarchy validation
test_header_hierarchy_integration() {
    local violations=0
    local output=$(capture_command "$CORE_DIR/commands/status")
    
    # Main command should have ONE primary header (with separator line)
    local separator_count=$(echo "$output" | grep -c " " || echo "0")
    
    # Status command should have at least one separator (the main header)
    if [ "$separator_count" -eq 0 ]; then
        echo "ERROR: Status command has no header separators"
        violations=$((violations + 1))
    fi
    
    # But not too many (avoid header overuse)
    if [ "$separator_count" -gt 3 ]; then
        echo "WARNING: Status command has many separators ($separator_count), may overuse header()"
        # This is a warning, not a failure
    fi
    
    return $violations
}

# Test 8: Color output validation (when available)
test_color_output_integration() {
    local violations=0
    
    # Test with forced color terminal
    TERM="xterm-256color" "$CORE_DIR/commands/status" > /tmp/color_test.out 2>&1 || true
    
    # If colors are being used, check for ANSI color codes
    if grep -q $'\033\[' /tmp/color_test.out; then
        # Good - colors are being applied
        
        # Check that colors are being reset properly (should have reset codes)
        if ! grep -q $'\033\[0m\|\033\[39m\|\033\[49m' /tmp/color_test.out; then
            echo "WARNING: Color output may not be properly reset"
            # This is a warning since it might affect terminal state
        fi
    fi
    
    rm -f /tmp/color_test.out
    return $violations
}

# Test 9: Message spacing and formatting
test_message_formatting_integration() {
    local violations=0
    local output=$(capture_command "$CORE_DIR/commands/relink" --dry-run)
    
    # Check for proper spacing - no double spaces after symbols
    if echo "$output" | grep -qE 'STDOUT:.*[!:]  '; then
        echo "ERROR: Commands have extra spaces after UI symbols"
        violations=$((violations + 1))
    fi
    
    # Check for trailing whitespace on lines
    if echo "$output" | grep -qE 'STDOUT:.*[[:space:]]$'; then
        echo "WARNING: Commands may have trailing whitespace"
        # This is cosmetic but worth noting
    fi
    
    # Check that indentation is consistent
    local indent_pattern=$(echo "$output" | grep -oE '^[[:space:]]*"' | head -1)
    if [ -n "$indent_pattern" ]; then
        local inconsistent_indents=$(echo "$output" | grep '"' | grep -v "$indent_pattern" | wc -l)
        if [ "$inconsistent_indents" -gt 0 ]; then
            echo "ERROR: Inconsistent list item indentation"
            violations=$((violations + 1))
        fi
    fi
    
    return $violations
}

# Test 10: Performance and output efficiency
test_output_efficiency() {
    local violations=0
    
    # Commands shouldn't produce excessive output for simple operations
    local status_lines=$(capture_command "$CORE_DIR/commands/status" | wc -l)
    local relink_lines=$(capture_command "$CORE_DIR/commands/relink" --dry-run | wc -l)
    
    # Reasonable limits (these are quite generous)
    if [ "$status_lines" -gt 200 ]; then
        echo "WARNING: Status command produces $status_lines lines (quite verbose)"
    fi
    
    if [ "$relink_lines" -gt 150 ]; then
        echo "WARNING: Relink dry-run produces $relink_lines lines (quite verbose)"
    fi
    
    # Check for repeated identical lines (possible inefficiency)
    local status_output=$(capture_command "$CORE_DIR/commands/status")
    local unique_lines=$(echo "$output" | sort | uniq | wc -l)
    local total_lines=$(echo "$output" | wc -l)
    
    if [ "$total_lines" -gt 10 ] && [ "$unique_lines" -lt $((total_lines / 2)) ]; then
        echo "WARNING: Status command has many repeated lines ($unique_lines unique of $total_lines total)"
    fi
    
    return $violations
}

# Main test runner
main() {
    echo ">ê Command Integration UI Tests"
    echo "============================================="
    echo ""
    
    # Run all integration tests
    run_test "Help command UI consistency" test_help_command_ui
    run_test "Status command UI structure" test_status_command_ui
    run_test "Relink dry-run UI consistency" test_relink_dry_run_ui
    run_test "Error command UI handling" test_error_command_ui
    run_test "Command help consistency" test_command_help_consistency
    run_test "Cross-command symbol consistency" test_cross_command_symbol_consistency
    run_test "Header hierarchy validation" test_header_hierarchy_integration
    run_test "Color output validation" test_color_output_integration
    run_test "Message formatting validation" test_message_formatting_integration
    run_test "Output efficiency check" test_output_efficiency
    
    # Summary
    echo "============================================="
    echo "Integration Test Results:"
    echo "  Total tests:  $TESTS_RUN"
    echo "  Passed:       $TESTS_PASSED"
    echo "  Failed:       $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo "L Command integration tests FAILED"
        echo ""
        echo "This indicates that actual command output has UI inconsistencies."
        echo "Run individual commands to see their output and fix formatting issues."
        exit 1
    else
        echo " All command integration tests PASSED"
        echo ""
        echo "Commands are producing consistent, well-formatted UI output!"
        exit 0
    fi
}

# Run tests
main "$@"