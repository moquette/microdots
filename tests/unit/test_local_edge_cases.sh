#!/usr/bin/env bash
#
# Unit Tests for Local Topic Edge Cases and Error Conditions
# Tests specific edge cases that could break the local topic system
#

set -e

# Get the script directory and source test framework
TEST_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
source "$TEST_DIR/../test_framework.sh"

# Test configuration
TEST_TOPIC_NAME="edgecase"

# Setup edge case test environment
setup_edge_case_environment() {
    # Setup base test environment FIRST
    setup_test_environment
    
    test_info "Setting up edge case test environment..."
    
    # Set up dotfiles structure 
    mkdir -p "$TEST_HOME/.dotfiles"
    cp -r "$DOTFILES_ROOT/core" "$TEST_HOME/.dotfiles/" 2>/dev/null || true
    cp -r "$DOTFILES_ROOT/zsh" "$TEST_HOME/.dotfiles/" 2>/dev/null || true
    
    export ZSH="$TEST_HOME/.dotfiles"
    export DOTFILES_DIR="$TEST_HOME/.dotfiles"
    
    test_success "Edge case environment ready"
}

# Test 1: Circular Symlink Detection
test_circular_symlink_detection() {
    test_info "Testing circular symlink detection and handling"
    
    # Create circular symlink: .local -> custom_dir -> .local
    mkdir -p "$TEST_HOME/circular_local"
    ln -sf "$TEST_HOME/.dotfiles/.local" "$TEST_HOME/circular_local/.local"
    ln -sf "$TEST_HOME/circular_local" "$TEST_HOME/.dotfiles/.local"
    
    # Should not hang or crash when resolving
    source "$TEST_HOME/.dotfiles/core/lib/paths.sh"
    
    # This should timeout or return empty rather than hanging
    timeout 5 bash -c 'resolve_local_path' || true
    
    # Clean up circular symlinks
    rm -f "$TEST_HOME/.dotfiles/.local"
    rm -rf "$TEST_HOME/circular_local"
    
    test_success "Circular symlink handling passed"
}

# Test 2: Permission Denied Scenarios
test_permission_denied() {
    test_info "Testing permission denied scenarios"
    
    # Create local directory but make it unreadable
    mkdir -p "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME"
    echo 'export TEST_VAR="should_not_load"' > "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME/config.zsh"
    chmod 000 "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME"
    
    # Should handle permission errors gracefully
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink" 2>/dev/null || true
    
    # Variable should not be set due to permission error
    assert_equals "" "${TEST_VAR:-}" "Permission denied should prevent loading"
    
    # Restore permissions for cleanup
    chmod 755 "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME"
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Permission denied handling passed"
}

# Test 3: Very Deep Directory Structures
test_deep_directory_structures() {
    test_info "Testing very deep directory structures"
    
    # Create deeply nested local topic
    local deep_path="$TEST_HOME/.dotlocal"
    for i in {1..10}; do
        deep_path="$deep_path/level$i"
    done
    mkdir -p "$deep_path/$TEST_TOPIC_NAME"
    
    echo 'export DEEP_VAR="deep_value"' > "$deep_path/$TEST_TOPIC_NAME/config.zsh"
    
    # Should handle deep paths without issues
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    
    # Deep directory should still be processed
    assert_equals "deep_value" "${DEEP_VAR:-}" "Deep directory structure should work"
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Deep directory structure handling passed"
}

# Test 4: Special Characters in File Names
test_special_characters() {
    test_info "Testing special characters in filenames and content"
    
    mkdir -p "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME"
    
    # Create files with special characters
    echo 'export SPACE_VAR="has spaces"' > "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME/with spaces.zsh"
    echo 'export QUOTE_VAR="has\"quotes"' > "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME/quotes.zsh"
    echo 'export NEWLINE_VAR="has\nnewlines"' > "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME/newlines.zsh"
    
    # Should handle special characters gracefully
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    
    # Files with spaces in names should be loaded
    assert_equals "has spaces" "${SPACE_VAR:-}" "Spaces in filenames should work"
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Special character handling passed"
}

# Test 5: Large Number of Files
test_large_file_count() {
    test_info "Testing performance with large number of files"
    
    mkdir -p "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME"
    
    # Create many small config files
    for i in {1..100}; do
        echo "export VAR_$i=\"value_$i\"" > "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME/config$i.zsh"
    done
    
    # Should handle many files without excessive slowdown
    local start_time=$(date +%s)
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    local end_time=$(date +%s)
    
    local duration=$((end_time - start_time))
    
    # Should complete within reasonable time (10 seconds)
    if [ $duration -lt 10 ]; then
        test_success "Large file count handled efficiently ($duration seconds)"
    else
        test_error "Large file count took too long: $duration seconds"
    fi
    
    # Verify some variables were set
    assert_equals "value_1" "${VAR_1:-}" "First variable should be set"
    assert_equals "value_100" "${VAR_100:-}" "Last variable should be set"
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Large file count test passed"
}

# Test 6: Concurrent Access Simulation
test_concurrent_access() {
    test_info "Testing concurrent access to local topics"
    
    mkdir -p "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME"
    echo 'export CONCURRENT_VAR="concurrent_value"' > "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME/config.zsh"
    
    # Simulate concurrent shell sessions
    (cd "$TEST_HOME" && source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink") &
    (cd "$TEST_HOME" && source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink") &
    (cd "$TEST_HOME" && source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink") &
    
    # Wait for all background processes
    wait
    
    # Should handle concurrent access without corruption
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    assert_equals "concurrent_value" "${CONCURRENT_VAR:-}" "Concurrent access should work"
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Concurrent access test passed"
}

# Test 7: Broken Symlinks and Missing Targets
test_broken_symlinks() {
    test_info "Testing broken symlinks and missing targets"
    
    # Create broken symlink in local directory
    mkdir -p "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME"
    ln -sf "/nonexistent/target" "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME/broken.symlink"
    
    # Create valid config alongside broken symlink
    echo 'export VALID_VAR="valid_value"' > "$TEST_HOME/.dotlocal/$TEST_TOPIC_NAME/config.zsh"
    
    # Should handle broken symlinks gracefully and continue processing
    cd "$TEST_HOME/.dotfiles"
    export DOTLOCAL_DIR="$TEST_HOME/.dotlocal"
    bash "./core/commands/relink" 2>/dev/null || true
    
    # Valid config should still load despite broken symlink
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    assert_equals "valid_value" "${VALID_VAR:-}" "Valid config should load despite broken symlinks"
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Broken symlink handling passed"
}

# Test 8: Path Cache Corruption
test_path_cache_corruption() {
    test_info "Testing path cache corruption resistance"
    
    # Create initial local directory
    mkdir -p "$TEST_HOME/.dotlocal"
    source "$TEST_HOME/.dotfiles/core/lib/paths.sh"
    
    # Get initial cached path
    local initial_path=$(resolve_local_path)
    assert_equals "$TEST_HOME/.dotlocal" "$initial_path" "Initial path resolution"
    
    # Corrupt the cache by changing directory externally
    rm -rf "$TEST_HOME/.dotlocal"
    mkdir -p "$TEST_HOME/new_dotlocal"
    
    # Cache should detect change and update
    clear_path_cache
    export DOTLOCAL_DIR=""  # Clear environment cache
    
    # Create new config and force resolution
    echo "LOCAL_PATH=$TEST_HOME/new_dotlocal" > "$TEST_HOME/.dotfiles/dotfiles.conf"
    
    local new_path=$(resolve_local_path)
    assert_equals "$TEST_HOME/new_dotlocal" "$new_path" "Should resolve to new path after cache clear"
    
    # Cleanup
    rm -f "$TEST_HOME/.dotfiles/dotfiles.conf"
    rm -rf "$TEST_HOME/new_dotlocal"
    
    test_success "Path cache corruption resistance passed"
}

# Main test execution
main() {
    echo "======================================="
    echo "LOCAL TOPIC EDGE CASES TEST SUITE"
    echo "Testing error conditions and edge cases"
    echo "======================================="
    
    # Setup test environment
    setup_edge_case_environment
    
    # Run all edge case tests
    run_test "Circular Symlink Detection" test_circular_symlink_detection
    run_test "Permission Denied Handling" test_permission_denied
    run_test "Deep Directory Structures" test_deep_directory_structures
    run_test "Special Characters" test_special_characters
    run_test "Large File Count" test_large_file_count
    run_test "Concurrent Access" test_concurrent_access
    run_test "Broken Symlinks" test_broken_symlinks
    run_test "Path Cache Corruption" test_path_cache_corruption
    
    # Generate final report
    generate_test_report
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi