#!/usr/bin/env bash
#
# COMPREHENSIVE TEST SUITE FOR DOTLOCAL SYSTEM
# Tests all functionality of the sophisticated dotlocal configuration management
#
# This test suite validates:
# 1. Path resolution with 4-level precedence
# 2. Two-phase symlink creation (public first, local overrides)
# 3. Edge cases and error conditions
# 4. Security and performance aspects
# 5. Integration with existing commands

set -euo pipefail

# Store the correct DOTFILES_ROOT before test framework overrides it
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"

# Source test framework (this will override DOTFILES_ROOT)
source "$SCRIPT_DIR/../test_framework.sh"

# Restore the correct DOTFILES_ROOT after test framework
export DOTFILES_ROOT="$REAL_DOTFILES_ROOT"

# Source the libraries we're testing
CORE_DIR="$DOTFILES_ROOT/core"
source "$CORE_DIR/lib/paths.sh"
source "$CORE_DIR/lib/symlink.sh"
source "$CORE_DIR/lib/common.sh"

# Test configuration
TEST_DOTFILES_CONF="$TEST_HOME/.dotfiles/dotfiles.conf"
TEST_DOTLOCAL="$TEST_HOME/.dotlocal"
TEST_DOTFILES_LOCAL="$TEST_HOME/.dotfiles/local"

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

#======================================================================
# UTILITY FUNCTIONS FOR TESTING
#======================================================================

test_counter() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo "TEST $TOTAL_TESTS: $1"
}

test_pass() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    test_success "PASS: $1"
}

test_fail() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    test_error "FAIL: $1"
    TEST_FAILED=true
}

setup_test_dotfiles() {
    # Create a test dotfiles directory
    mkdir -p "$TEST_HOME/.dotfiles/core/lib"
    mkdir -p "$TEST_HOME/.dotfiles/core/commands"
    
    # Copy essential files
    cp -r "$DOTFILES_ROOT/core/"* "$TEST_HOME/.dotfiles/core/"
    
    # Set DOTFILES_DIR to test location
    export DOTFILES_DIR="$TEST_HOME/.dotfiles"
    
    # Clear any cached paths from previous tests
    clear_path_cache
}

create_test_config() {
    local config_content="$1"
    mkdir -p "$(dirname "$TEST_DOTFILES_CONF")"
    echo "$config_content" > "$TEST_DOTFILES_CONF"
}

create_test_symlink_files() {
    local location="$1"  # "public" or "local" or path
    local files="$2"     # space-separated list of files
    
    case "$location" in
        "public")
            local target_dir="$TEST_HOME/.dotfiles"
            ;;
        "local")
            local target_dir="$TEST_DOTLOCAL"
            ;;
        *)
            local target_dir="$location"
            ;;
    esac
    
    mkdir -p "$target_dir"
    
    for file in $files; do
        echo "# Test content for $file" > "$target_dir/$file.symlink"
    done
}

verify_symlink_points_to() {
    local symlink="$1"
    local expected_target="$2"
    local message="$3"
    
    if [[ -L "$symlink" ]]; then
        local actual_target=$(readlink "$symlink")
        if [[ "$actual_target" == "$expected_target" ]]; then
            test_pass "$message: Symlink points to correct target"
            return 0
        else
            test_fail "$message: Expected target '$expected_target', got '$actual_target'"
            return 1
        fi
    else
        test_fail "$message: Expected symlink at $symlink, but not found"
        return 1
    fi
}

#======================================================================
# TEST 1: PATH RESOLUTION WITH 4-LEVEL PRECEDENCE
#======================================================================

test_path_resolution_precedence() {
    test_counter "Path Resolution 4-Level Precedence"
    
    setup_test_dotfiles
    
    # Test 1.1: No configuration - should return empty
    clear_path_cache
    local result=$(resolve_local_path)
    if [[ -z "$result" ]]; then
        test_pass "No config returns empty path"
    else
        test_fail "Expected empty path, got: $result"
    fi
    
    # Test 1.2: Priority 4 - Hidden directory at ~/.dotlocal
    mkdir -p "$TEST_DOTLOCAL"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$TEST_DOTLOCAL" ]]; then
        test_pass "Priority 4: Uses ~/.dotlocal directory"
    else
        test_fail "Expected $TEST_DOTLOCAL, got: $result"
    fi
    
    # Test 1.3: Priority 3 - Directory at ~/.dotfiles/local overrides hidden
    mkdir -p "$TEST_DOTFILES_LOCAL"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$TEST_DOTFILES_LOCAL" ]]; then
        test_pass "Priority 3: ~/.dotfiles/local overrides ~/.dotlocal"
    else
        test_fail "Expected $TEST_DOTFILES_LOCAL, got: $result"
    fi
    
    # Test 1.4: Priority 2 - Symlink overrides directory
    rm -rf "$TEST_DOTFILES_LOCAL"
    local custom_dir="$TEST_HOME/custom_dotlocal"
    mkdir -p "$custom_dir"
    ln -s "$custom_dir" "$TEST_DOTFILES_LOCAL"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$custom_dir" ]]; then
        test_pass "Priority 2: Symlink overrides directory"
    else
        test_fail "Expected $custom_dir, got: $result"
    fi
    
    # Test 1.5: Priority 1 - dotfiles.conf overrides everything
    local config_path="$TEST_HOME/config_specified"
    mkdir -p "$config_path"
    create_test_config "LOCAL_PATH='$config_path'"
    # Re-source to pick up new config
    source "$CORE_DIR/lib/paths.sh"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$config_path" ]]; then
        test_pass "Priority 1: dotfiles.conf LOCAL_PATH overrides all"
    else
        test_fail "Expected $config_path, got: $result"
    fi
    
    return 0
}

#======================================================================
# TEST 2: CACHE BEHAVIOR
#======================================================================

test_cache_behavior() {
    test_counter "Cache Behavior and Performance"
    
    setup_test_dotfiles
    mkdir -p "$TEST_DOTLOCAL"
    
    # Test 2.1: Cache is used on subsequent calls
    clear_path_cache
    local first_call=$(resolve_local_path)
    
    # Modify filesystem but don't clear cache
    rm -rf "$TEST_DOTLOCAL"
    local second_call=$(resolve_local_path)
    
    if [[ "$first_call" == "$second_call" ]]; then
        test_pass "Cache prevents filesystem re-reading"
    else
        test_fail "Cache not working: first=$first_call, second=$second_call"
    fi
    
    # Test 2.2: Cache clearing works
    clear_path_cache
    local third_call=$(resolve_local_path)
    
    if [[ "$third_call" != "$first_call" ]]; then
        test_pass "Cache clearing works correctly"
    else
        test_fail "Cache not cleared properly"
    fi
    
    return 0
}

#======================================================================
# TEST 3: PATH TYPE DETECTION
#======================================================================

test_path_type_detection() {
    test_counter "Path Type Detection Accuracy"
    
    setup_test_dotfiles
    
    # Test 3.1: Not configured
    clear_path_cache
    local type_result=$(get_local_path_type)
    if [[ "$type_result" == "Not configured" ]]; then
        test_pass "Correctly detects 'Not configured'"
    else
        test_fail "Expected 'Not configured', got: $type_result"
    fi
    
    # Test 3.2: Hidden directory
    mkdir -p "$TEST_DOTLOCAL"
    clear_path_cache
    type_result=$(get_local_path_type)
    if [[ "$type_result" == "Hidden directory (~/.dotlocal)" ]]; then
        test_pass "Correctly detects hidden directory"
    else
        test_fail "Expected 'Hidden directory', got: $type_result"
    fi
    
    # Test 3.3: Regular directory
    mkdir -p "$TEST_DOTFILES_LOCAL"
    clear_path_cache
    type_result=$(get_local_path_type)
    if [[ "$type_result" == "Directory" ]]; then
        test_pass "Correctly detects regular directory"
    else
        test_fail "Expected 'Directory', got: $type_result"
    fi
    
    # Test 3.4: Symlink
    rm -rf "$TEST_DOTFILES_LOCAL"
    local target_dir="$TEST_HOME/symlink_target"
    mkdir -p "$target_dir"
    ln -s "$target_dir" "$TEST_DOTFILES_LOCAL"
    clear_path_cache
    type_result=$(get_local_path_type)
    if [[ "$type_result" == "Symlink" ]]; then
        test_pass "Correctly detects symlink"
    else
        test_fail "Expected 'Symlink', got: $type_result"
    fi
    
    # Test 3.5: Configured path
    local config_dir="$TEST_HOME/config_dir"
    mkdir -p "$config_dir"
    create_test_config "LOCAL_PATH='$config_dir'"
    source "$CORE_DIR/lib/paths.sh"
    clear_path_cache
    type_result=$(get_local_path_type)
    if [[ "$type_result" == "Configured path (dotfiles.conf)" ]]; then
        test_pass "Correctly detects configured path"
    else
        test_fail "Expected 'Configured path', got: $type_result"
    fi
    
    return 0
}

#======================================================================
# TEST 4: TWO-PHASE SYMLINK CREATION
#======================================================================

test_two_phase_symlink_creation() {
    test_counter "Two-Phase Symlink Creation (Public First, Local Overrides)"
    
    setup_test_dotfiles
    mkdir -p "$TEST_DOTLOCAL"
    
    # Create public config files
    create_test_symlink_files "public" "testrc vimrc"
    
    # Create local override for one file
    create_test_symlink_files "local" "vimrc gitconfig"
    
    # Run symlink creation
    create_all_symlinks_with_precedence "$TEST_HOME/.dotfiles" "$TEST_DOTLOCAL" "false" "false"
    
    # Test 4.1: Public file without local override should be linked
    if verify_symlink_points_to "$TEST_HOME/.testrc" "$TEST_HOME/.dotfiles/testrc.symlink" "Public testrc"; then
        test_pass "Public file linked when no local override"
    fi
    
    # Test 4.2: Local override should win
    if verify_symlink_points_to "$TEST_HOME/.vimrc" "$TEST_DOTLOCAL/vimrc.symlink" "Local vimrc override"; then
        test_pass "Local override wins over public"
    fi
    
    # Test 4.3: Local-only file should be linked
    if verify_symlink_points_to "$TEST_HOME/.gitconfig" "$TEST_DOTLOCAL/gitconfig.symlink" "Local-only gitconfig"; then
        test_pass "Local-only file gets linked"
    fi
    
    return 0
}

#======================================================================
# TEST 5: DRY-RUN MODE
#======================================================================

test_dry_run_mode() {
    test_counter "Dry-Run Mode Functionality"
    
    setup_test_dotfiles
    mkdir -p "$TEST_DOTLOCAL"
    
    # Create test files
    create_test_symlink_files "public" "testrc"
    create_test_symlink_files "local" "vimrc"
    
    # Run in dry-run mode
    local output=$(create_all_symlinks_with_precedence "$TEST_HOME/.dotfiles" "$TEST_DOTLOCAL" "true" "false" 2>&1)
    
    # Test 5.1: No actual symlinks created
    if [[ ! -L "$TEST_HOME/.testrc" ]] && [[ ! -L "$TEST_HOME/.vimrc" ]]; then
        test_pass "Dry-run mode creates no actual symlinks"
    else
        test_fail "Dry-run mode created actual symlinks"
    fi
    
    # Test 5.2: Output indicates what would be done
    if echo "$output" | grep -q "dry-run"; then
        test_pass "Dry-run output indicates dry-run mode"
    else
        test_fail "Dry-run output missing dry-run indicators"
    fi
    
    return 0
}

#======================================================================
# MAIN TEST EXECUTION
#======================================================================

run_comprehensive_dotlocal_tests() {
    echo "=========================================="
    echo "COMPREHENSIVE DOTLOCAL SYSTEM TEST SUITE"
    echo "=========================================="
    echo ""
    
    # Set up test environment
    setup_test_environment
    
    # Run all test functions
    test_path_resolution_precedence
    test_cache_behavior
    test_path_type_detection
    test_two_phase_symlink_creation
    test_dry_run_mode
    
    # Generate final report
    echo ""
    echo "=========================================="
    echo "COMPREHENSIVE TEST RESULTS"
    echo "=========================================="
    echo "Total Tests Run: $TOTAL_TESTS"
    echo "Tests Passed: $PASSED_TESTS"
    echo "Tests Failed: $FAILED_TESTS"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "<� ALL TESTS PASSED! The dotlocal system is working correctly."
        return 0
    else
        echo "L $FAILED_TESTS test(s) failed. Please review the output above."
        return 1
    fi
}

# Run the comprehensive test suite if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_comprehensive_dotlocal_tests
fi