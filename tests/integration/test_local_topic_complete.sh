#!/usr/bin/env bash
#
# Comprehensive Integration Tests for Local Topic Functionality
# Tests all aspects of the .local/dotlocal system after recent changes
#
# CRITICAL: Tests the new .local directory (not local) and full topic support
#

set -e

# Get the script directory and source test framework
TEST_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
source "$TEST_DIR/../test_framework.sh"

# Test configuration
TEST_TOPIC_NAME="testlocal"
LOCAL_TEST_DIR=""

# Setup comprehensive test environment
setup_local_test_environment() {
    # Setup base test environment FIRST
    setup_test_environment
    
    test_info "Setting up comprehensive local topic test environment..."
    
    # Set up proper dotfiles structure in test home
    mkdir -p "$TEST_HOME/.dotfiles"
    
    # Copy core files to test environment
    cp -r "$DOTFILES_ROOT/core" "$TEST_HOME/.dotfiles/" 2>/dev/null || true
    cp -r "$DOTFILES_ROOT/zsh" "$TEST_HOME/.dotfiles/" 2>/dev/null || true
    cp -r "$DOTFILES_ROOT/bin" "$TEST_HOME/.dotfiles/" 2>/dev/null || true
    
    # Set environment variables for tests
    export ZSH="$TEST_HOME/.dotfiles"
    export DOTFILES_DIR="$TEST_HOME/.dotfiles"
    
    # Create test local directory (using .local not local)
    LOCAL_TEST_DIR="$TEST_HOME/.dotlocal"
    mkdir -p "$LOCAL_TEST_DIR"
    
    test_success "Local test environment ready"
}

# Clean up test topics
cleanup_test_topics() {
    rm -rf "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME" 2>/dev/null || true
    rm -rf "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME" 2>/dev/null || true
    rm -rf "$TEST_HOME/.dotfiles/.local" 2>/dev/null || true
}

# Test 1: Directory Resolution Tests
test_local_directory_resolution() {
    test_info "Testing local directory resolution (.local vs local)"
    
    cleanup_test_topics
    
    # Test 1a: ~/.dotlocal fallback (standard case)
    mkdir -p "$TEST_HOME/.dotlocal"
    source "$TEST_HOME/.dotfiles/core/lib/paths.sh"
    local resolved_path=$(resolve_local_path)
    assert_equals "$TEST_HOME/.dotlocal" "$resolved_path" "Should resolve to ~/.dotlocal"
    
    # Test 1b: ~/.dotfiles/.local directory takes precedence
    mkdir -p "$TEST_HOME/.dotfiles/.local"
    clear_path_cache
    resolved_path=$(resolve_local_path)
    assert_equals "$TEST_HOME/.dotfiles/.local" "$resolved_path" "Should prefer .local directory"
    
    # Test 1c: ~/.dotfiles/.local symlink takes highest precedence
    rm -rf "$TEST_HOME/.dotfiles/.local"
    ln -sf "$TEST_HOME/.dotlocal" "$TEST_HOME/.dotfiles/.local"
    clear_path_cache
    resolved_path=$(resolve_local_path)
    assert_equals "$TEST_HOME/.dotlocal" "$resolved_path" "Should follow symlink to ~/.dotlocal"
    
    # Test 1d: dotfiles.conf override takes ultimate precedence
    echo "LOCAL_PATH=$TEST_HOME/custom_local" > "$TEST_HOME/.dotfiles/dotfiles.conf"
    mkdir -p "$TEST_HOME/custom_local"
    clear_path_cache
    resolved_path=$(resolve_local_path)
    assert_equals "$TEST_HOME/custom_local" "$resolved_path" "Should use dotfiles.conf LOCAL_PATH"
    
    # Cleanup
    rm -f "$TEST_HOME/.dotfiles/dotfiles.conf"
    rm -rf "$TEST_HOME/custom_local"
    rm -f "$TEST_HOME/.dotfiles/.local"
    
    test_success "Directory resolution tests passed"
}

# Test 2: Local Topic Loading Order Tests  
test_local_loading_order() {
    test_info "Testing local topic loading order (public first, local second)"
    
    cleanup_test_topics
    
    # Create public topic with path.zsh, config.zsh, completion.zsh
    mkdir -p "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME"
    echo 'export TEST_PATH_VAR="public_path"' > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/path.zsh"
    echo 'export TEST_CONFIG_VAR="public_config"' > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/config.zsh"
    echo 'export TEST_COMPLETION_VAR="public_completion"' > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/completion.zsh"
    
    # Create local topic that overrides all
    mkdir -p "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME"
    echo 'export TEST_PATH_VAR="local_path"' > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/path.zsh"
    echo 'export TEST_CONFIG_VAR="local_config"' > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/config.zsh"
    echo 'export TEST_COMPLETION_VAR="local_completion"' > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/completion.zsh"
    
    # Source zshrc which should load both public and local (local wins)
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    
    # Verify local values won (loaded last)
    assert_equals "local_path" "${TEST_PATH_VAR:-}" "Local path.zsh should override public"
    assert_equals "local_config" "${TEST_CONFIG_VAR:-}" "Local config.zsh should override public"
    assert_equals "local_completion" "${TEST_COMPLETION_VAR:-}" "Local completion.zsh should override public"
    
    test_success "Loading order tests passed"
}

# Test 3: Stage-Based Loading Tests
test_stage_based_loading() {
    test_info "Testing four-stage loading with local override"
    
    cleanup_test_topics
    
    # Create tracking variables to verify loading order
    export LOAD_ORDER=""
    
    # Public topic with all stages
    mkdir -p "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME"
    echo 'export LOAD_ORDER="${LOAD_ORDER}:pub_path"' > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/path.zsh"
    echo 'export LOAD_ORDER="${LOAD_ORDER}:pub_config"' > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/aliases.zsh"
    echo 'export LOAD_ORDER="${LOAD_ORDER}:pub_completion"' > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/completion.zsh"
    
    # Local topic with all stages  
    mkdir -p "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME"
    echo 'export LOAD_ORDER="${LOAD_ORDER}:local_path"' > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/path.zsh"
    echo 'export LOAD_ORDER="${LOAD_ORDER}:local_config"' > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/aliases.zsh"
    echo 'export LOAD_ORDER="${LOAD_ORDER}:local_completion"' > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/completion.zsh"
    
    # Load the shell configuration
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    
    # Expected order: pub_path -> local_path -> pub_config -> local_config -> pub_completion -> local_completion
    local expected_order=":pub_path:local_path:pub_config:local_config:pub_completion:local_completion"
    assert_equals "$expected_order" "${LOAD_ORDER:-}" "Loading order should be stage-based with local override"
    
    test_success "Stage-based loading tests passed"
}

# Test 4: Install.sh Processing Tests  
test_local_install_processing() {
    test_info "Testing local install.sh processing"
    
    cleanup_test_topics
    
    # Create public topic with install script
    mkdir -p "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME"
    cat > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/install.sh" << 'EOF'
#!/usr/bin/env bash
echo "public_install_marker" > "$TEST_TEMP_DIR/public_install_executed"
EOF
    chmod +x "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/install.sh"
    
    # Create local topic with install script
    mkdir -p "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME"
    cat > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/install.sh" << 'EOF'
#!/usr/bin/env bash
echo "local_install_marker" > "$TEST_TEMP_DIR/local_install_executed"
EOF
    chmod +x "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/install.sh"
    
    # Run install command
    cd "$TEST_HOME/.dotfiles"
    export DOTLOCAL_DIR="$LOCAL_TEST_DIR"
    bash "./core/commands/install"
    
    # Verify both install scripts ran
    assert_file_exists "$TEST_TEMP_DIR/public_install_executed" "Public install.sh should have executed"
    assert_file_exists "$TEST_TEMP_DIR/local_install_executed" "Local install.sh should have executed"
    
    # Verify content of marker files
    if [[ -f "$TEST_TEMP_DIR/public_install_executed" ]]; then
        local public_content=$(cat "$TEST_TEMP_DIR/public_install_executed")
        assert_equals "public_install_marker" "$public_content" "Public install marker content"
    fi
    
    if [[ -f "$TEST_TEMP_DIR/local_install_executed" ]]; then
        local local_content=$(cat "$TEST_TEMP_DIR/local_install_executed")
        assert_equals "local_install_marker" "$local_content" "Local install marker content"
    fi
    
    test_success "Install processing tests passed"
}

# Test 5: Mixed Topic Scenarios
test_mixed_topic_scenarios() {
    test_info "Testing mixed scenarios (public only, local only, both)"
    
    cleanup_test_topics
    
    # Scenario 1: Public topic only
    mkdir -p "$TEST_HOME/.dotfiles/public_only"
    echo 'export PUBLIC_ONLY_VAR="public_value"' > "$TEST_HOME/.dotfiles/public_only/config.zsh"
    
    # Scenario 2: Local topic only  
    mkdir -p "$LOCAL_TEST_DIR/local_only"
    echo 'export LOCAL_ONLY_VAR="local_value"' > "$LOCAL_TEST_DIR/local_only/config.zsh"
    
    # Scenario 3: Both topics (local should override)
    mkdir -p "$TEST_HOME/.dotfiles/both_topics"
    echo 'export BOTH_TOPICS_VAR="public_value"' > "$TEST_HOME/.dotfiles/both_topics/config.zsh"
    mkdir -p "$LOCAL_TEST_DIR/both_topics"
    echo 'export BOTH_TOPICS_VAR="local_value"' > "$LOCAL_TEST_DIR/both_topics/config.zsh"
    
    # Load configuration
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    
    # Test all scenarios
    assert_equals "public_value" "${PUBLIC_ONLY_VAR:-}" "Public-only topic should work"
    assert_equals "local_value" "${LOCAL_ONLY_VAR:-}" "Local-only topic should work"
    assert_equals "local_value" "${BOTH_TOPICS_VAR:-}" "Local should override public in mixed scenario"
    
    # Cleanup test topics
    rm -rf "$TEST_HOME/.dotfiles/public_only"
    rm -rf "$TEST_HOME/.dotfiles/both_topics"
    rm -rf "$LOCAL_TEST_DIR/local_only"
    rm -rf "$LOCAL_TEST_DIR/both_topics"
    
    test_success "Mixed scenario tests passed"
}

# Test 6: Symlink Processing Tests
test_local_symlink_processing() {
    test_info "Testing local .symlink file processing"
    
    cleanup_test_topics
    
    # Create public topic with symlink file
    mkdir -p "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME"
    echo "# Public config file" > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/testrc.symlink"
    
    # Create local topic with symlink file (should override)
    mkdir -p "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME"
    echo "# Local config file" > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/testrc.symlink"
    
    # Run relink to process symlinks
    cd "$TEST_HOME/.dotfiles"
    export DOTLOCAL_DIR="$LOCAL_TEST_DIR"
    bash "./core/commands/relink"
    
    # Verify symlink was created and points to local version
    assert_file_exists "$TEST_HOME/.testrc" "Symlink should be created"
    
    if [[ -f "$TEST_HOME/.testrc" ]]; then
        local content=$(cat "$TEST_HOME/.testrc")
        assert_contains "$content" "Local config file" "Symlink should point to local version"
    fi
    
    test_success "Symlink processing tests passed"
}

# Test 7: Error Handling and Edge Cases
test_error_handling() {
    test_info "Testing error handling and edge cases"
    
    cleanup_test_topics
    
    # Test 7a: Empty local directory should not break loading
    mkdir -p "$LOCAL_TEST_DIR/empty_topic"
    
    cd "$TEST_HOME"
    assert_command_succeeds "source $TEST_HOME/.dotfiles/zsh/zshrc.symlink" "Empty local topic should not break loading"
    
    # Test 7b: Malformed zsh files should not break shell
    mkdir -p "$LOCAL_TEST_DIR/malformed_topic"
    echo 'export INCOMPLETE_VAR=' > "$LOCAL_TEST_DIR/malformed_topic/config.zsh"  # Incomplete export
    
    # Should still load without fatal error
    assert_command_succeeds "source $TEST_HOME/.dotfiles/zsh/zshrc.symlink" "Malformed files should not break loading"
    
    # Test 7c: Missing local directory should gracefully fallback
    rm -rf "$LOCAL_TEST_DIR"
    clear_path_cache
    
    cd "$TEST_HOME"
    assert_command_succeeds "source $TEST_HOME/.dotfiles/zsh/zshrc.symlink" "Missing local directory should not break loading"
    
    # Recreate local dir for other tests
    mkdir -p "$LOCAL_TEST_DIR"
    
    # Cleanup
    rm -rf "$LOCAL_TEST_DIR/empty_topic"
    rm -rf "$LOCAL_TEST_DIR/malformed_topic"
    
    test_success "Error handling tests passed"
}

# Test 8: Integration with Core Commands
test_core_command_integration() {
    test_info "Testing integration with core commands (status, relink, etc.)"
    
    cleanup_test_topics
    
    # Setup both public and local topics
    mkdir -p "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME"
    echo "# Public config" > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/config.zsh"
    echo "# Public symlink" > "$TEST_HOME/.dotfiles/$TEST_TOPIC_NAME/test.symlink"
    
    mkdir -p "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME"
    echo "# Local config" > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/config.zsh"
    echo "# Local symlink" > "$LOCAL_TEST_DIR/$TEST_TOPIC_NAME/test.symlink"
    
    # Test status command recognizes local directory
    cd "$TEST_HOME/.dotfiles"
    export DOTLOCAL_DIR="$LOCAL_TEST_DIR"
    local status_output=$(bash "./core/commands/status" 2>&1 || true)
    
    # Should mention local configuration
    assert_contains "$status_output" "Local" "Status should show local directory info"
    
    # Test relink processes both public and local
    bash "./core/commands/relink"
    
    # Verify symlink was created (local should win)
    assert_file_exists "$TEST_HOME/.test" "Relink should create symlinks"
    
    if [[ -f "$TEST_HOME/.test" ]]; then
        local symlink_content=$(cat "$TEST_HOME/.test")
        assert_contains "$symlink_content" "Local symlink" "Local symlink should override public"
    fi
    
    test_success "Core command integration tests passed"
}

# Main test execution
main() {
    echo "=========================================="
    echo "LOCAL TOPIC COMPREHENSIVE TEST SUITE"
    echo "Testing .local directory functionality"
    echo "=========================================="
    
    # Setup test environment
    setup_local_test_environment
    
    # Run all test suites
    run_test "Local Directory Resolution" test_local_directory_resolution
    run_test "Local Loading Order" test_local_loading_order  
    run_test "Stage-Based Loading" test_stage_based_loading
    run_test "Install.sh Processing" test_local_install_processing
    run_test "Mixed Topic Scenarios" test_mixed_topic_scenarios
    run_test "Symlink Processing" test_local_symlink_processing
    run_test "Error Handling" test_error_handling
    run_test "Core Command Integration" test_core_command_integration
    
    # Generate final report
    generate_test_report
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi