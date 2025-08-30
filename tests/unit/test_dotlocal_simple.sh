#!/usr/bin/env bash
#
# COMPREHENSIVE DOTLOCAL SYSTEM TESTING
# Testing the sophisticated dotlocal configuration management system
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
TEST_TEMP_DIR="/tmp/dotlocal_test_$$"
TEST_HOME="$TEST_TEMP_DIR/home"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Utility functions
info() { echo -e "${BLUE}INFO:${NC} $1"; }
success() { echo -e "${GREEN}${NC} $1"; }
warning() { echo -e "${YELLOW} ${NC} $1"; }
error() { echo -e "${RED}${NC} $1"; }

test_pass() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    success "PASS: $1"
}

test_fail() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    error "FAIL: $1"
}

test_start() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
    echo "TEST $TOTAL_TESTS: $1"
    echo "----------------------------------------"
}

# Setup test environment
setup_test() {
    rm -rf "$TEST_TEMP_DIR"
    mkdir -p "$TEST_HOME/.dotfiles/core"
    
    # Copy core libraries to test location
    cp -r "$DOTFILES_ROOT/core/"* "$TEST_HOME/.dotfiles/core/"
    
    # Set environment variables for test
    export HOME="$TEST_HOME"
    export DOTFILES_DIR="$TEST_HOME/.dotfiles"
    
    # Source the libraries
    source "$TEST_HOME/.dotfiles/core/lib/paths.sh"
    source "$TEST_HOME/.dotfiles/core/lib/symlink.sh"
}

# Cleanup
cleanup_test() {
    rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
}

#===============================================================================
# CORE DOTLOCAL SYSTEM TESTS
#===============================================================================

test_precedence_rules() {
    test_start "Path Resolution 4-Level Precedence"
    
    setup_test
    
    # Test 1: No configuration
    clear_path_cache
    result=$(resolve_local_path)
    if [[ -z "$result" ]]; then
        test_pass "No config returns empty path"
    else
        test_fail "Expected empty, got: '$result'"
    fi
    
    # Test 2: ~/.dotlocal directory (Priority 4)
    mkdir -p "$HOME/.dotlocal"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$HOME/.dotlocal" ]]; then
        test_pass "Priority 4: Uses ~/.dotlocal"
    else
        test_fail "Expected ~/.dotlocal, got: '$result'"
    fi
    
    # Test 3: ~/.dotfiles/local directory (Priority 3)
    mkdir -p "$HOME/.dotfiles/local"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$HOME/.dotfiles/local" ]]; then
        test_pass "Priority 3: ~/.dotfiles/local overrides ~/.dotlocal"
    else
        test_fail "Expected ~/.dotfiles/local, got: '$result'"
    fi
    
    # Test 4: Symlink (Priority 2)
    rm -rf "$HOME/.dotfiles/local"
    local target_dir="$HOME/custom_local"
    mkdir -p "$target_dir"
    ln -s "$target_dir" "$HOME/.dotfiles/local"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$target_dir" ]]; then
        test_pass "Priority 2: Symlink overrides directory"
    else
        test_fail "Expected symlink target '$target_dir', got: '$result'"
    fi
    
    # Test 5: dotfiles.conf (Priority 1)
    local config_dir="$HOME/config_specified"
    mkdir -p "$config_dir"
    cat > "$HOME/.dotfiles/dotfiles.conf" << EOF
LOCAL_PATH='$config_dir'
EOF
    # Re-source to pick up config
    source "$HOME/.dotfiles/core/lib/paths.sh"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$config_dir" ]]; then
        test_pass "Priority 1: dotfiles.conf overrides all"
    else
        test_fail "Expected config path '$config_dir', got: '$result'"
    fi
}

test_path_type_detection() {
    test_start "Path Type Detection"
    
    setup_test
    
    # Test: Not configured
    clear_path_cache
    type_result=$(get_local_path_type)
    if [[ "$type_result" == "Not configured" ]]; then
        test_pass "Detects 'Not configured' state"
    else
        test_fail "Expected 'Not configured', got: '$type_result'"
    fi
    
    # Test: Hidden directory
    mkdir -p "$HOME/.dotlocal"
    clear_path_cache
    type_result=$(get_local_path_type)
    if [[ "$type_result" == "Hidden directory (~/.dotlocal)" ]]; then
        test_pass "Detects hidden directory type"
    else
        test_fail "Expected 'Hidden directory', got: '$type_result'"
    fi
    
    # Test: Regular directory
    mkdir -p "$HOME/.dotfiles/local"
    clear_path_cache
    type_result=$(get_local_path_type)
    if [[ "$type_result" == "Directory" ]]; then
        test_pass "Detects regular directory type"
    else
        test_fail "Expected 'Directory', got: '$type_result'"
    fi
}

test_cache_functionality() {
    test_start "Cache Behavior"
    
    setup_test
    mkdir -p "$HOME/.dotlocal"
    
    # Test: Cache works
    clear_path_cache
    first_call=$(resolve_local_path)
    
    # Remove directory but don't clear cache
    rm -rf "$HOME/.dotlocal"
    second_call=$(resolve_local_path)
    
    if [[ "$first_call" == "$second_call" ]]; then
        test_pass "Cache prevents filesystem re-reading"
    else
        test_fail "Cache not working properly"
    fi
    
    # Test: Cache clearing works
    clear_path_cache
    third_call=$(resolve_local_path)
    if [[ "$third_call" != "$first_call" ]]; then
        test_pass "Cache clearing works"
    else
        test_fail "Cache not cleared"
    fi
}

test_symlink_precedence() {
    test_start "Two-Phase Symlink Creation"
    
    setup_test
    mkdir -p "$HOME/.dotlocal"
    
    # Create public config
    mkdir -p "$HOME/.dotfiles"
    echo "# Public vimrc" > "$HOME/.dotfiles/vimrc.symlink"
    echo "# Public testrc" > "$HOME/.dotfiles/testrc.symlink"
    
    # Create local override
    echo "# Local vimrc override" > "$HOME/.dotlocal/vimrc.symlink"
    echo "# Local only gitconfig" > "$HOME/.dotlocal/gitconfig.symlink"
    
    # Run symlink creation
    create_all_symlinks_with_precedence "$HOME/.dotfiles" "$HOME/.dotlocal" "false" "true" >/dev/null 2>&1
    
    # Test: Public file without local override
    if [[ -L "$HOME/.testrc" ]]; then
        target=$(readlink "$HOME/.testrc")
        if [[ "$target" == "$HOME/.dotfiles/testrc.symlink" ]]; then
            test_pass "Public file linked when no local override"
        else
            test_fail "Public file points to wrong target: $target"
        fi
    else
        test_fail "Public file not linked"
    fi
    
    # Test: Local override wins
    if [[ -L "$HOME/.vimrc" ]]; then
        target=$(readlink "$HOME/.vimrc")
        if [[ "$target" == "$HOME/.dotlocal/vimrc.symlink" ]]; then
            test_pass "Local override wins over public"
        else
            test_fail "Local override not working: $target"
        fi
    else
        test_fail "Local override not linked"
    fi
    
    # Test: Local-only file
    if [[ -L "$HOME/.gitconfig" ]]; then
        target=$(readlink "$HOME/.gitconfig")
        if [[ "$target" == "$HOME/.dotlocal/gitconfig.symlink" ]]; then
            test_pass "Local-only file gets linked"
        else
            test_fail "Local-only file wrong target: $target"
        fi
    else
        test_fail "Local-only file not linked"
    fi
}

test_dry_run_mode() {
    test_start "Dry-Run Mode"
    
    setup_test
    mkdir -p "$HOME/.dotlocal"
    
    # Create test files
    echo "# Test" > "$HOME/.dotfiles/testrc.symlink"
    echo "# Test" > "$HOME/.dotlocal/vimrc.symlink"
    
    # Run in dry-run mode
    output=$(create_all_symlinks_with_precedence "$HOME/.dotfiles" "$HOME/.dotlocal" "true" "false" 2>&1)
    
    # Test: No actual symlinks created
    if [[ ! -L "$HOME/.testrc" && ! -L "$HOME/.vimrc" ]]; then
        test_pass "Dry-run creates no actual symlinks"
    else
        test_fail "Dry-run created actual symlinks"
    fi
    
    # Test: Output indicates dry-run
    if echo "$output" | grep -q "dry-run"; then
        test_pass "Dry-run output correctly labeled"
    else
        test_fail "Dry-run output missing indicators"
    fi
}

test_edge_cases() {
    test_start "Edge Cases and Error Handling"
    
    setup_test
    
    # Test: Broken symlink handling
    ln -s "/nonexistent" "$HOME/.dotfiles/local"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ -z "$result" ]]; then
        test_pass "Handles broken symlinks gracefully"
    else
        test_fail "Should not return path for broken symlink: $result"
    fi
    rm -f "$HOME/.dotfiles/local"
    
    # Test: Non-existent configured path
    cat > "$HOME/.dotfiles/dotfiles.conf" << EOF
LOCAL_PATH='/nonexistent/path'
EOF
    source "$HOME/.dotfiles/core/lib/paths.sh"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ -z "$result" ]]; then
        test_pass "Handles non-existent configured path"
    else
        test_fail "Should not return non-existent path: $result"
    fi
    
    # Test: Special characters in paths
    special_dir="$HOME/path with spaces & symbols"
    mkdir -p "$special_dir"
    cat > "$HOME/.dotfiles/dotfiles.conf" << EOF
LOCAL_PATH='$special_dir'
EOF
    source "$HOME/.dotfiles/core/lib/paths.sh"
    clear_path_cache
    result=$(resolve_local_path)
    if [[ "$result" == "$special_dir" ]]; then
        test_pass "Handles special characters in paths"
    else
        test_fail "Failed with special characters: '$result'"
    fi
}

test_command_integration() {
    test_start "Command Integration"
    
    setup_test
    
    # Test: dots status works (basic check)
    if command -v "$DOTFILES_ROOT/bin/dots" >/dev/null 2>&1; then
        # Set up proper environment for dots command
        export HOME="$TEST_HOME"
        export DOTFILES_DIR="$TEST_HOME/.dotfiles"
        
        # Run dots status with timeout
        if timeout 10 "$DOTFILES_ROOT/bin/dots" status >/dev/null 2>&1; then
            test_pass "dots status command works"
        else
            test_fail "dots status command failed or timed out"
        fi
    else
        warning "dots command not available for testing"
    fi
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    echo "=========================================="
    echo "COMPREHENSIVE DOTLOCAL SYSTEM TEST SUITE"
    echo "=========================================="
    echo ""
    info "Testing dotlocal system functionality..."
    echo ""
    
    # Run all tests
    test_precedence_rules
    test_path_type_detection  
    test_cache_functionality
    test_symlink_precedence
    test_dry_run_mode
    test_edge_cases
    test_command_integration
    
    # Cleanup
    cleanup_test
    
    # Final report
    echo ""
    echo "=========================================="
    echo "FINAL TEST RESULTS"
    echo "=========================================="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        success "<‰ ALL TESTS PASSED! dotlocal system is working correctly."
        return 0
    else
        error "L $FAILED_TESTS test(s) failed."
        return 1
    fi
}

# Handle cleanup on exit
trap cleanup_test EXIT

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi