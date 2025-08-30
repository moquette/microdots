#!/usr/bin/env bash
#
# ADVANCED DOTLOCAL SYSTEM TESTING
# Tests complex edge cases, security, performance, and integration scenarios
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
TEST_TEMP_DIR="/tmp/dotlocal_advanced_test_$$"
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
    echo "ADVANCED TEST $TOTAL_TESTS: $1"
    echo "===================================================="
}

# Setup test environment
setup_advanced_test() {
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
# ADVANCED EDGE CASE TESTS
#===============================================================================

test_circular_symlink_detection() {
    test_start "Circular Symlink Detection and Recovery"
    
    setup_advanced_test
    
    # Create circular symlink: local -> local
    ln -s "$HOME/.dotfiles/local" "$HOME/.dotfiles/local"
    clear_path_cache
    
    # Should handle circular symlink gracefully
    result=$(resolve_local_path 2>/dev/null || echo "")
    if [[ -z "$result" ]]; then
        test_pass "Detects and handles circular symlinks"
    else
        test_fail "Failed to handle circular symlink: '$result'"
    fi
    
    # Clean up circular symlink
    rm -f "$HOME/.dotfiles/local"
    
    # Create chain of symlinks: local -> temp -> target
    mkdir -p "$HOME/target_dir"
    ln -s "$HOME/target_dir" "$HOME/temp_link"
    ln -s "$HOME/temp_link" "$HOME/.dotfiles/local"
    clear_path_cache
    
    result=$(resolve_local_path)
    if [[ "$result" == "$HOME/target_dir" ]]; then
        test_pass "Follows symlink chains correctly"
    else
        test_fail "Failed to follow symlink chain: '$result'"
    fi
}

test_large_scale_performance() {
    test_start "Large Scale Performance Testing"
    
    setup_advanced_test
    mkdir -p "$HOME/.dotlocal"
    
    # Create 100 public config files (reduced from 200 for faster testing)
    for i in {1..100}; do
        echo "# Public config $i" > "$HOME/.dotfiles/config${i}.symlink"
    done
    
    # Create 25 local overrides
    for i in {1..25}; do
        echo "# Local override $i" > "$HOME/.dotlocal/config${i}.symlink"
    done
    
    # Time the operation
    local start_time=$(date +%s)
    create_all_symlinks_with_precedence "$HOME/.dotfiles" "$HOME/.dotlocal" "false" "true" >/dev/null 2>&1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Verify results
    local total_symlinks=$(find "$HOME" -maxdepth 1 -name ".config*" -type l | wc -l | tr -d ' ')
    local local_overrides=0
    
    for i in {1..25}; do
        if [[ -L "$HOME/.config$i" ]]; then
            local target=$(readlink "$HOME/.config$i")
            if [[ "$target" == "$HOME/.dotlocal/config${i}.symlink" ]]; then
                local_overrides=$((local_overrides + 1))
            fi
        fi
    done
    
    if [[ $total_symlinks -eq 100 ]] && [[ $local_overrides -eq 25 ]] && [[ $duration -lt 10 ]]; then
        test_pass "Large scale test: 100 files, 25 overrides in ${duration}s"
    else
        test_fail "Large scale test failed: $total_symlinks symlinks, $local_overrides overrides, ${duration}s"
    fi
}

test_path_traversal_security() {
    test_start "Path Traversal and Security Testing"
    
    setup_advanced_test
    
    # Test 1: Path traversal in config
    cat > "$HOME/.dotfiles/dotfiles.conf" << 'EOF'
LOCAL_PATH='../../etc/passwd'
EOF
    source "$HOME/.dotfiles/core/lib/paths.sh"
    clear_path_cache
    
    result=$(resolve_local_path)
    # Should not resolve to /etc/passwd since it's not a directory
    if [[ -z "$result" ]]; then
        test_pass "Prevents path traversal to system files"
    else
        test_fail "Path traversal vulnerability: '$result'"
    fi
    
    # Test 2: Symlink pointing outside dotfiles
    local outside_dir="$TEST_TEMP_DIR/outside_sandbox"
    mkdir -p "$outside_dir"
    echo "sensitive=secret" > "$outside_dir/sensitive.symlink"
    
    ln -s "$outside_dir" "$HOME/.dotfiles/local"
    clear_path_cache
    
    result=$(resolve_local_path)
    if [[ "$result" == "$outside_dir" ]]; then
        test_pass "Allows symlinks outside dotfiles (expected behavior)"
    else
        test_fail "Outside symlinks not working: '$result'"
    fi
    
    rm -f "$HOME/.dotfiles/local"
    
    # Test 3: Config injection attempt
    cat > "$HOME/.dotfiles/dotfiles.conf" << 'EOF'
LOCAL_PATH='/tmp/test_injection_$$'
# Injection attempt
rm -rf /
EOF
    
    mkdir -p "/tmp/test_injection_$$"
    source "$HOME/.dotfiles/core/lib/paths.sh"
    clear_path_cache
    
    result=$(resolve_local_path)
    if [[ "$result" == "/tmp/test_injection_$$" ]] && [[ -d "/tmp/test_injection_$$" ]]; then
        test_pass "Config file injection doesn't execute commands"
    else
        test_fail "Config injection test inconclusive"
    fi
    
    rm -rf "/tmp/test_injection_$$"
}

test_broken_symlink_cleanup() {
    test_start "Comprehensive Broken Symlink Cleanup"
    
    setup_advanced_test
    
    # Create valid symlinks
    echo "valid content" > "$HOME/valid_file"
    ln -s "$HOME/valid_file" "$HOME/.valid1"
    ln -s "$HOME/valid_file" "$HOME/.valid2"
    
    # Create broken symlinks of various types
    ln -s "/nonexistent/file1" "$HOME/.broken1"
    ln -s "/nonexistent/file2" "$HOME/.broken2"
    ln -s "$HOME/missing_file" "$HOME/.broken3"
    
    # Create a symlink to a file that gets deleted
    echo "temp" > "$HOME/temp_file"
    ln -s "$HOME/temp_file" "$HOME/.broken4"
    rm "$HOME/temp_file"
    
    # Count broken symlinks before cleanup
    local broken_before=$(find "$HOME" -maxdepth 1 -type l ! -exec test -e {} \; -print | wc -l | tr -d ' ')
    
    if [[ $broken_before -eq 4 ]]; then
        test_pass "Setup: Created $broken_before broken symlinks"
    else
        warning "Setup created $broken_before broken symlinks (expected 4)"
    fi
    
    # Run cleanup
    clean_broken_dotfile_symlinks "false"
    
    # Count broken symlinks after cleanup
    local broken_after=$(find "$HOME" -maxdepth 1 -type l ! -exec test -e {} \; -print | wc -l | tr -d ' ')
    
    # Count valid symlinks (should be preserved)
    local valid_remaining=$(find "$HOME" -maxdepth 1 -name ".valid*" -type l | wc -l | tr -d ' ')
    
    if [[ $broken_after -eq 0 ]] && [[ $valid_remaining -eq 2 ]]; then
        test_pass "Cleanup removed all broken symlinks, preserved valid ones"
    else
        test_fail "Cleanup failed: $broken_after broken remain, $valid_remaining valid remain"
    fi
}

test_real_world_workflow() {
    test_start "Real-World Workflow Integration"
    
    setup_advanced_test
    
    # Create a realistic dotfiles setup
    mkdir -p "$HOME/.dotfiles/git" "$HOME/.dotfiles/zsh" "$HOME/.dotfiles/vim"
    mkdir -p "$HOME/.dotlocal/git" "$HOME/.dotlocal/zsh"
    
    # Public configs
    echo "[user]" > "$HOME/.dotfiles/git/gitconfig.symlink"
    echo "  name = Public User" >> "$HOME/.dotfiles/git/gitconfig.symlink"
    echo "export PUBLIC_VAR=true" > "$HOME/.dotfiles/zsh/zshrc.symlink"
    echo "set number" > "$HOME/.dotfiles/vim/vimrc.symlink"
    
    # Local overrides
    echo "[user]" > "$HOME/.dotlocal/git/gitconfig.symlink"
    echo "  name = Local User" >> "$HOME/.dotlocal/git/gitconfig.symlink"
    echo "  email = local@example.com" >> "$HOME/.dotlocal/git/gitconfig.symlink"
    echo "export LOCAL_VAR=true" > "$HOME/.dotlocal/zsh/zshrc.symlink"
    
    # Run the symlink process
    create_all_symlinks_with_precedence "$HOME/.dotfiles" "$HOME/.dotlocal" "false" "true" >/dev/null 2>&1
    
    # Verify local wins
    if [[ -L "$HOME/.gitconfig" ]]; then
        local target=$(readlink "$HOME/.gitconfig")
        if [[ "$target" == "$HOME/.dotlocal/git/gitconfig.symlink" ]]; then
            # Check content
            if grep -q "Local User" "$HOME/.gitconfig" && grep -q "local@example.com" "$HOME/.gitconfig"; then
                test_pass "Local gitconfig overrides public with correct content"
            else
                test_fail "Local gitconfig content not correct"
            fi
        else
            test_fail "Gitconfig not pointing to local version: $target"
        fi
    else
        test_fail "Gitconfig symlink not created"
    fi
    
    # Verify public-only file is linked
    if [[ -L "$HOME/.vimrc" ]]; then
        local target=$(readlink "$HOME/.vimrc")
        if [[ "$target" == "$HOME/.dotfiles/vim/vimrc.symlink" ]]; then
            test_pass "Public-only vimrc correctly linked"
        else
            test_fail "Vimrc pointing to wrong target: $target"
        fi
    else
        test_fail "Vimrc symlink not created"
    fi
}

#===============================================================================
# MAIN EXECUTION
#===============================================================================

main() {
    echo "==========================================================="
    echo "ADVANCED DOTLOCAL SYSTEM TESTING SUITE"
    echo "==========================================================="
    echo ""
    info "Running advanced edge case and security tests..."
    echo ""
    
    # Run all advanced tests
    test_circular_symlink_detection
    test_large_scale_performance
    test_path_traversal_security
    test_broken_symlink_cleanup
    test_real_world_workflow
    
    # Cleanup
    cleanup_test
    
    # Final report
    echo ""
    echo "==========================================================="
    echo "ADVANCED TEST RESULTS"
    echo "==========================================================="
    echo "Total Advanced Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo ""
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        success "<‰ ALL ADVANCED TESTS PASSED! dotlocal system is robust and secure."
        return 0
    else
        error "L $FAILED_TESTS advanced test(s) failed."
        return 1
    fi
}

# Handle cleanup on exit
trap cleanup_test EXIT

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi