#!/usr/bin/env bash
#
# Command Substitution Safety Test Suite
# Ensures no functions used in command substitution contaminate stdout
#

set -euo pipefail

# Test framework
source "$(dirname "$0")/test_framework.sh"

TEST_SUITE="Command Substitution Safety"

# Test that discover_dotlocal_path returns clean output
test_discover_dotlocal_path_clean() {
    local test_name="discover_dotlocal_path returns clean output"

    cd "$DOTFILES_ROOT"
    source core/lib/paths.sh

    # Clear cache for clean test
    clear_dotlocal_cache >/dev/null 2>&1

    # Capture stdout only (no stderr)
    local result
    result=$(discover_dotlocal_path "$HOME/.dotfiles" "true" 2>/dev/null)

    # Check result is a clean path
    if [[ "$result" =~ ^/.*$ ]] && [[ ! "$result" =~ $'\n' ]] && [[ ! "$result" =~ "›" ]] && [[ ! "$result" =~ "✓" ]]; then
        pass_test "$test_name" "Returns clean path: '$result'"
    else
        fail_test "$test_name" "Contaminated output: '$result'"
    fi
}

# Test that resolve_dotlocal_path returns clean output
test_resolve_dotlocal_path_clean() {
    local test_name="resolve_dotlocal_path returns clean output"

    cd "$DOTFILES_ROOT"
    source core/lib/paths.sh

    # Clear cache for clean test
    clear_dotlocal_cache >/dev/null 2>&1

    # Test with verbose=true (the dangerous case)
    local result
    result=$(resolve_dotlocal_path "$HOME/.dotfiles" "false" "true" 2>/dev/null)

    # Check result is a clean path
    if [[ "$result" =~ ^/.*$ ]] && [[ ! "$result" =~ $'\n' ]] && [[ ! "$result" =~ "›" ]] && [[ ! "$result" =~ "✓" ]]; then
        pass_test "$test_name" "Returns clean path: '$result'"
    else
        fail_test "$test_name" "Contaminated output: '$result'"
    fi
}

# Test that get_dotlocal_discovery_method returns clean output
test_get_discovery_method_clean() {
    local test_name="get_dotlocal_discovery_method returns clean output"

    cd "$DOTFILES_ROOT"
    source core/lib/paths.sh

    # Set up state first
    clear_dotlocal_cache >/dev/null 2>&1
    discover_dotlocal_path "$HOME/.dotfiles" "false" >/dev/null 2>&1

    # Test the method function
    local result
    result=$(get_dotlocal_discovery_method)

    # Check result is clean text (no UI symbols)
    if [[ -n "$result" ]] && [[ ! "$result" =~ "›" ]] && [[ ! "$result" =~ "✓" ]] && [[ ! "$result" =~ $'\n' ]]; then
        pass_test "$test_name" "Returns clean method: '$result'"
    else
        fail_test "$test_name" "Contaminated output: '$result'"
    fi
}

# Test that get_dotlocal_type returns clean output
test_get_dotlocal_type_clean() {
    local test_name="get_dotlocal_type returns clean output"

    cd "$DOTFILES_ROOT"
    source core/lib/paths.sh

    local result
    result=$(get_dotlocal_type "$HOME/.dotfiles")

    # Check result is one of the expected clean types
    case "$result" in
        "explicit"|"symlink"|"directory"|"standard"|"none")
            pass_test "$test_name" "Returns clean type: '$result'"
            ;;
        *)
            fail_test "$test_name" "Unexpected type: '$result'"
            ;;
    esac
}

# Test stderr vs stdout separation
test_stderr_stdout_separation() {
    local test_name="stderr/stdout properly separated"

    cd "$DOTFILES_ROOT"
    source core/lib/paths.sh

    clear_dotlocal_cache >/dev/null 2>&1

    # Capture stdout and stderr separately
    local stdout_file stderr_file
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)

    discover_dotlocal_path "$HOME/.dotfiles" "true" >"$stdout_file" 2>"$stderr_file"

    local stdout_content stderr_content
    stdout_content=$(cat "$stdout_file")
    stderr_content=$(cat "$stderr_file")

    rm -f "$stdout_file" "$stderr_file"

    # Stdout should be clean path only
    # Stderr should contain debug messages
    if [[ "$stdout_content" =~ ^/.*$ ]] && [[ ! "$stdout_content" =~ "›" ]] && \
       [[ "$stderr_content" =~ "›" ]] && [[ "$stderr_content" =~ "Starting 5-level" ]]; then
        pass_test "$test_name" "Clean stdout, debug on stderr"
    else
        fail_test "$test_name" "stdout: '$stdout_content', stderr: '$stderr_content'"
    fi
}

# Test bootstrap-style usage
test_bootstrap_pattern() {
    local test_name="bootstrap command substitution pattern works"

    cd "$DOTFILES_ROOT"
    source core/lib/paths.sh

    clear_dotlocal_cache >/dev/null 2>&1

    # Simulate the exact bootstrap pattern
    local discovered_path
    discovered_path=$(resolve_dotlocal_path "$DOTFILES_ROOT" "true" "true")

    # Should get clean path without debug contamination
    if [[ "$discovered_path" =~ ^/.*$ ]] && [[ ! "$discovered_path" =~ $'\n' ]] && \
       [[ ! "$discovered_path" =~ "›" ]] && [[ ! "$discovered_path" =~ "✓" ]]; then
        pass_test "$test_name" "Bootstrap pattern returns clean path"
    else
        fail_test "$test_name" "Bootstrap pattern contaminated: '$discovered_path'"
    fi
}

# Test edge case: multiple calls don't accumulate contamination
test_multiple_calls_safe() {
    local test_name="multiple calls don't accumulate contamination"

    cd "$DOTFILES_ROOT"
    source core/lib/paths.sh

    # Multiple calls with caching
    local result1 result2 result3
    clear_dotlocal_cache >/dev/null 2>&1

    result1=$(discover_dotlocal_path "$HOME/.dotfiles" "true" 2>/dev/null)
    result2=$(discover_dotlocal_path "$HOME/.dotfiles" "true" 2>/dev/null)  # Should use cache
    result3=$(discover_dotlocal_path "$HOME/.dotfiles" "false" 2>/dev/null) # Different verbose setting

    if [[ "$result1" == "$result2" ]] && [[ "$result2" == "$result3" ]] && \
       [[ "$result1" =~ ^/.*$ ]] && [[ ! "$result1" =~ "›" ]]; then
        pass_test "$test_name" "All calls return same clean path"
    else
        fail_test "$test_name" "Results differ or contaminated: '$result1' '$result2' '$result3'"
    fi
}

# Test that UI functions properly redirect to stderr when called with >&2
test_ui_function_stderr_redirect() {
    local test_name="UI functions properly redirect to stderr"

    cd "$DOTFILES_ROOT"
    source core/lib/common.sh

    # Test info function with explicit stderr redirect
    local stdout_file stderr_file
    stdout_file=$(mktemp)
    stderr_file=$(mktemp)

    (info "test message" >&2) >"$stdout_file" 2>"$stderr_file"

    local stdout_content stderr_content
    stdout_content=$(cat "$stdout_file")
    stderr_content=$(cat "$stderr_file")

    rm -f "$stdout_file" "$stderr_file"

    if [[ -z "$stdout_content" ]] && [[ "$stderr_content" =~ "test message" ]]; then
        pass_test "$test_name" "UI function properly redirected to stderr"
    else
        fail_test "$test_name" "stdout: '$stdout_content', stderr: '$stderr_content'"
    fi
}

# Run all tests
main() {
    start_test_suite "$TEST_SUITE"

    test_discover_dotlocal_path_clean
    test_resolve_dotlocal_path_clean
    test_get_discovery_method_clean
    test_get_dotlocal_type_clean
    test_stderr_stdout_separation
    test_bootstrap_pattern
    test_multiple_calls_safe
    test_ui_function_stderr_redirect

    finish_test_suite
}

main "$@"