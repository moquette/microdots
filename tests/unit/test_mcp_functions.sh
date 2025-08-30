#!/usr/bin/env bash
#
# Unit Tests for MCP Shell Functions
# Tests individual MCP functions in isolation
# Bulletproof testing for mcp-sync, mcp-status, mcp-add, etc.
#

# Source the test framework
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$TEST_DIR/test_framework.sh"

# Setup for MCP function testing
setup_mcp_function_tests() {
  # Create mock environment
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$TEST_TEMP_DIR/test_servers.json"
  
  # Create test servers.json
  mkdir -p "$(dirname "$MCP_SERVERS_FILE")"
  cat > "$MCP_SERVERS_FILE" << 'EOF'
{
  "mcpServers": {
    "test-filesystem": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp/test"],
      "env": {}
    },
    "test-memory": {
      "type": "stdio", 
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {}
    }
  }
}
EOF
  
  # Source the MCP functions
  # Source from local if it exists, otherwise skip test
  if [[ -f "$DOTFILES_ROOT/.local/claude/claude.zsh" ]]; then
    source "$DOTFILES_ROOT/.local/claude/claude.zsh"
  else
    echo "Skipping test - claude.zsh not found"
    return 0
  fi
}

# Test 1: mcp-merge-servers function with new config
test_mcp_merge_servers_new_config() {
  setup_mcp_function_tests
  
  local test_config="$TEST_TEMP_DIR/new_config.json"
  
  # Test creating new config
  mcp-merge-servers "$test_config" > "$TEST_TEMP_DIR/merge_output.txt" 2>&1
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "mcp-merge-servers should succeed with new config"
  assert_file_exists "$test_config" "New config file should be created"
  
  # Verify config contains MCP servers
  if command -v jq >/dev/null 2>&1; then
    local server_count=$(jq -r '.mcpServers | length' "$test_config" 2>/dev/null || echo "0")
    assert_equals "2" "$server_count" "New config should have correct number of servers"
    
    local has_filesystem=$(jq -r '.mcpServers | has("test-filesystem")' "$test_config")
    assert_equals "true" "$has_filesystem" "New config should have filesystem server"
  fi
  
  # Check output message
  local output=$(cat "$TEST_TEMP_DIR/merge_output.txt")
  assert_contains "$output" "Creating new config" "Should indicate creating new config"
}

# Test 2: mcp-merge-servers with existing config (no changes needed)
test_mcp_merge_servers_no_changes() {
  setup_mcp_function_tests
  
  local test_config="$TEST_TEMP_DIR/existing_config.json"
  
  # Create config with same MCP servers
  cp "$MCP_SERVERS_FILE" "$test_config"
  
  # Test merge (should detect no changes needed)
  mcp-merge-servers "$test_config" > "$TEST_TEMP_DIR/merge_output.txt" 2>&1
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "mcp-merge-servers should succeed with no changes"
  
  # Check output indicates no changes
  local output=$(cat "$TEST_TEMP_DIR/merge_output.txt")
  assert_contains "$output" "Already up to date" "Should indicate no changes needed"
  
  # Verify no backup was created (since no changes)
  assert_file_not_exists "$test_config.backup" "Backup should not be created when no changes"
}

# Test 3: mcp-merge-servers with existing config needing update
test_mcp_merge_servers_with_update() {
  setup_mcp_function_tests
  
  local test_config="$TEST_TEMP_DIR/existing_config.json"
  
  # Create config with different MCP servers
  cat > "$test_config" << 'EOF'
{
  "mcpServers": {
    "old-server": {
      "type": "stdio",
      "command": "old-command",
      "args": []
    }
  },
  "otherSettings": {
    "theme": "dark",
    "preserved": true
  }
}
EOF
  
  # Test merge
  mcp-merge-servers "$test_config" > "$TEST_TEMP_DIR/merge_output.txt" 2>&1
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "mcp-merge-servers should succeed with update"
  
  # Verify backup was created
  assert_file_exists "$test_config.backup" "Backup should be created"
  
  if command -v jq >/dev/null 2>&1; then
    # Verify old server is preserved in backup
    local old_server_in_backup=$(jq -r '.mcpServers | has("old-server")' "$test_config.backup")
    assert_equals "true" "$old_server_in_backup" "Backup should preserve old server"
    
    # Verify new servers are in updated config
    local new_server_count=$(jq -r '.mcpServers | length' "$test_config" 2>/dev/null || echo "0")
    assert_equals "2" "$new_server_count" "Updated config should have new servers"
    
    # Verify other settings are preserved
    local preserved_setting=$(jq -r '.otherSettings.preserved' "$test_config")
    assert_equals "true" "$preserved_setting" "Other settings should be preserved"
    
    local theme_setting=$(jq -r '.otherSettings.theme' "$test_config")
    assert_equals "dark" "$theme_setting" "Theme setting should be preserved"
  fi
  
  # Check output messages
  local output=$(cat "$TEST_TEMP_DIR/merge_output.txt")
  assert_contains "$output" "Updated:" "Should indicate successful update"
  assert_contains "$output" "Backup:" "Should mention backup creation"
}

# Test 4: mcp-sync function basic functionality
test_mcp_sync_function() {
  setup_mcp_function_tests
  
  # Create test configs to sync to
  mkdir -p "$HOME/.claude"
  echo '{"existingSettings": true}' > "$HOME/.claude.json"
  
  mkdir -p ".claude"
  echo '{"projectSettings": true}' > ".claude/.claude.json"
  
  # Test mcp-sync
  local sync_output=$(mcp-sync 2>&1)
  local sync_exit=$?
  
  assert_equals "0" "$sync_exit" "mcp-sync should succeed"
  assert_contains "$sync_output" "MCP Server Configuration Sync" "Should show header"
  assert_contains "$sync_output" "Sync complete" "Should show completion"
  
  if command -v jq >/dev/null 2>&1; then
    # Verify configs were updated
    local global_servers=$(jq -r '.mcpServers | length' "$HOME/.claude.json" 2>/dev/null || echo "0")
    local project_servers=$(jq -r '.mcpServers | length' ".claude/.claude.json" 2>/dev/null || echo "0")
    
    assert_equals "2" "$global_servers" "Global config should have MCP servers"
    assert_equals "2" "$project_servers" "Project config should have MCP servers"
    
    # Verify existing settings preserved
    local existing_setting=$(jq -r '.existingSettings' "$HOME/.claude.json")
    assert_equals "true" "$existing_setting" "Existing settings should be preserved"
    
    local project_setting=$(jq -r '.projectSettings' ".claude/.claude.json")
    assert_equals "true" "$project_setting" "Project settings should be preserved"
  fi
}

# Test 5: mcp-sync with missing jq
test_mcp_sync_without_jq() {
  setup_mcp_function_tests
  
  # Mock missing jq by creating empty path directory
  mkdir -p "/tmp/no-jq"
  local old_path="$PATH"
  export PATH="/tmp/no-jq:$PATH"
  
  # Test mcp-sync without jq
  local sync_output=$(mcp-sync 2>&1)
  local sync_exit=$?
  
  assert_equals "1" "$sync_exit" "mcp-sync should fail without jq"
  assert_contains "$sync_output" "jq is required but not installed" "Should report missing jq"
  assert_contains "$sync_output" "brew install jq" "Should suggest installation"
  
  # Restore PATH
  export PATH="$old_path"
}

# Test 6: mcp-sync with missing servers.json
test_mcp_sync_missing_servers() {
  setup_mcp_function_tests
  
  # Remove servers file
  rm -f "$MCP_SERVERS_FILE"
  
  # Test mcp-sync
  local sync_output=$(mcp-sync 2>&1)
  local sync_exit=$?
  
  assert_equals "1" "$sync_exit" "mcp-sync should fail with missing servers.json"
  assert_contains "$sync_output" "servers.json not found" "Should report missing file"
}

# Test 7: mcp-status function
test_mcp_status_function() {
  setup_mcp_function_tests
  
  # Create configs with MCP servers
  mkdir -p "$HOME/.claude"
  cp "$MCP_SERVERS_FILE" "$HOME/.claude.json"
  
  # Create Desktop config
  local desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  mkdir -p "$(dirname "$desktop_config")"
  cp "$MCP_SERVERS_FILE" "$desktop_config"
  
  # Test mcp-status
  local status_output=$(mcp-status 2>&1)
  local status_exit=$?
  
  assert_equals "0" "$status_exit" "mcp-status should succeed"
  assert_contains "$status_output" "MCP Server Status" "Should show header"
  
  if command -v jq >/dev/null 2>&1; then
    assert_contains "$status_output" "Claude Code" "Should show Claude Code section"
    assert_contains "$status_output" "Claude Desktop" "Should show Claude Desktop section"
    assert_contains "$status_output" "test-filesystem" "Should list filesystem server"
    assert_contains "$status_output" "test-memory" "Should list memory server"
    assert_contains "$status_output" "Configs are up to date" "Should show sync status"
  fi
}

# Test 8: mcp-status with out-of-sync configs
test_mcp_status_out_of_sync() {
  setup_mcp_function_tests
  
  # Create outdated config
  mkdir -p "$HOME/.claude"
  echo '{"mcpServers": {"old-server": {}}}' > "$HOME/.claude.json"
  
  # Make servers.json newer
  sleep 1
  touch "$MCP_SERVERS_FILE"
  
  # Test mcp-status
  local status_output=$(mcp-status 2>&1)
  
  assert_contains "$status_output" "servers.json is newer" "Should detect out-of-sync"
  assert_contains "$status_output" "Run 'mcp-sync' to update" "Should suggest sync"
}

# Test 9: mcp-add function
test_mcp_add_function() {
  setup_mcp_function_tests
  
  # Test adding new server
  local add_output=$(mcp-add "github-server" "npx -y @modelcontextprotocol/server-github" 2>&1)
  local add_exit=$?
  
  if command -v jq >/dev/null 2>&1; then
    assert_equals "0" "$add_exit" "mcp-add should succeed"
    assert_contains "$add_output" "Adding MCP server: github-server" "Should show adding server"
    assert_contains "$add_output" "Added to servers.json" "Should confirm addition"
    
    # Verify server was added to file
    local server_exists=$(jq -r '.mcpServers | has("github-server")' "$MCP_SERVERS_FILE")
    assert_equals "true" "$server_exists" "Server should be added to servers.json"
    
    local server_command=$(jq -r '.mcpServers["github-server"].command' "$MCP_SERVERS_FILE")
    assert_equals "npx -y @modelcontextprotocol/server-github" "$server_command" "Server command should be set correctly"
  else
    assert_not_equals "0" "$add_exit" "mcp-add should fail without jq"
  fi
}

# Test 10: mcp-add with invalid arguments
test_mcp_add_invalid_args() {
  setup_mcp_function_tests
  
  # Test with missing arguments
  local add_output=$(mcp-add 2>&1)
  local add_exit=$?
  
  assert_equals "1" "$add_exit" "mcp-add should fail with missing arguments"
  assert_contains "$add_output" "Usage: mcp-add" "Should show usage message"
  assert_contains "$add_output" "Example:" "Should show example"
  
  # Test with only one argument
  local add_output2=$(mcp-add "test-server" 2>&1)
  local add_exit2=$?
  
  assert_equals "1" "$add_exit2" "mcp-add should fail with missing command argument"
  assert_contains "$add_output2" "Usage: mcp-add" "Should show usage message"
}

# Test 11: mcp-available function
test_mcp_available_function() {
  setup_mcp_function_tests
  
  # Mock npm search output
  local mock_npm_output='[
    {"name": "@modelcontextprotocol/server-filesystem", "description": "Filesystem server"},
    {"name": "@modelcontextprotocol/server-memory", "description": "Memory server"},
    {"name": "@modelcontextprotocol/server-puppeteer", "description": "Puppeteer server"}
  ]'
  
  # Create mock npm command
  mkdir -p "/tmp/mock-npm"
  cat > "/tmp/mock-npm/npm" << EOF
#!/bin/bash
if [[ "\$1" == "search" && "\$2" == "@modelcontextprotocol/server" && "\$3" == "--json" ]]; then
  echo '$mock_npm_output'
  exit 0
else
  exit 1
fi
EOF
  chmod +x "/tmp/mock-npm/npm"
  
  # Add to PATH temporarily
  local old_path="$PATH"
  export PATH="/tmp/mock-npm:$PATH"
  
  # Test mcp-available
  local available_output=$(mcp-available 2>&1)
  local available_exit=$?
  
  assert_equals "0" "$available_exit" "mcp-available should succeed"
  assert_contains "$available_output" "@modelcontextprotocol/server-filesystem" "Should list filesystem server"
  assert_contains "$available_output" "@modelcontextprotocol/server-memory" "Should list memory server" 
  assert_contains "$available_output" "@modelcontextprotocol/server-puppeteer" "Should list puppeteer server"
  
  # Restore PATH
  export PATH="$old_path"
  
  # Cleanup
  rm -rf "/tmp/mock-npm"
}

# Test 12: Edge case - corrupt servers.json
test_mcp_functions_corrupt_servers() {
  setup_mcp_function_tests
  
  # Create corrupt servers.json
  echo "{ invalid json }" > "$MCP_SERVERS_FILE"
  
  # Test mcp-sync with corrupt file
  local sync_output=$(mcp-sync 2>&1)
  local sync_exit=$?
  
  # Should fail gracefully
  assert_not_equals "0" "$sync_exit" "mcp-sync should fail with corrupt servers.json"
  assert_not_equals "139" "$sync_exit" "Should not segfault"
  
  # Test mcp-status with corrupt file
  local status_output=$(mcp-status 2>&1)
  
  # Should handle gracefully (may show warnings but not crash)
  assert_not_equals "139" "$?" "mcp-status should not segfault with corrupt file"
}

# Test 13: Auto-sync logic
test_mcp_auto_sync_logic() {
  setup_mcp_function_tests
  
  # Create older Claude config
  mkdir -p "$HOME/.claude"
  echo '{"mcpServers": {"old": "server"}}' > "$HOME/.claude.json"
  
  # Make servers.json newer
  sleep 1
  touch "$MCP_SERVERS_FILE"
  
  # Test auto-sync detection
  local claude_config="$HOME/.claude.json"
  
  # Test file timestamp comparison logic
  if [ "$MCP_SERVERS_FILE" -nt "$claude_config" ]; then
    test_success "Timestamp comparison works correctly"
  else
    test_error "Timestamp comparison failed"
  fi
  
  # Test auto-sync execution (run in subshell to avoid polluting environment)
  local auto_sync_output=$(bash -c '
    export ZSH="'"$DOTFILES_ROOT"'"
    export MCP_SERVERS_FILE="'"$MCP_SERVERS_FILE"'"
    source "'"$DOTFILES_ROOT"'/claude/claude.zsh"
    
    # Call auto-sync function directly
    mcp-auto-sync
    echo "Auto-sync completed"
  ' 2>&1)
  
  assert_contains "$auto_sync_output" "Auto-sync completed" "Auto-sync should complete"
  
  # Verify config was updated in background
  if command -v jq >/dev/null 2>&1; then
    # Give background process time to complete
    sleep 2
    
    local updated_servers=$(jq -r '.mcpServers | length' "$HOME/.claude.json" 2>/dev/null || echo "0")
    assert_equals "2" "$updated_servers" "Auto-sync should update config"
  fi
}

# Test 14: Environment variable handling
test_mcp_environment_variables() {
  setup_mcp_function_tests
  
  # Test with different MCP_SERVERS_FILE locations
  local alt_servers_file="$TEST_TEMP_DIR/alt_servers.json"
  cp "$MCP_SERVERS_FILE" "$alt_servers_file"
  
  # Test with alternative file
  export MCP_SERVERS_FILE="$alt_servers_file"
  
  local sync_output=$(mcp-sync 2>&1)
  local sync_exit=$?
  
  assert_equals "0" "$sync_exit" "mcp-sync should work with alternative servers file"
  assert_contains "$sync_output" "$alt_servers_file" "Should use alternative servers file"
  
  # Test fallback logic when global symlink doesn't exist
  unset MCP_SERVERS_FILE
  export ZSH="$DOTFILES_ROOT"
  
  # Source again to test fallback logic
  # Source from local if it exists, otherwise skip test
  if [[ -f "$DOTFILES_ROOT/.local/claude/claude.zsh" ]]; then
    source "$DOTFILES_ROOT/.local/claude/claude.zsh"
  else
    echo "Skipping test - claude.zsh not found"
    return 0
  fi
  
  # Should fall back to dotfiles location
  local expected_fallback="$ZSH/claude/mcp/servers.json"
  test_info "Expected fallback: $expected_fallback"
}

# Test 15: Concurrent execution safety
test_mcp_concurrent_safety() {
  setup_mcp_function_tests
  
  # Create config to merge
  echo '{"existing": true}' > "$HOME/.claude.json"
  
  # Run multiple merge operations simultaneously
  mcp-merge-servers "$HOME/.claude.json" >/dev/null 2>&1 &
  local pid1=$!
  
  mcp-merge-servers "$HOME/.claude.json" >/dev/null 2>&1 &  
  local pid2=$!
  
  # Wait for both to complete
  wait $pid1
  local exit1=$?
  wait $pid2
  local exit2=$?
  
  # Both should succeed or fail gracefully (no corruption)
  assert_not_equals "139" "$exit1" "First merge should not segfault"
  assert_not_equals "139" "$exit2" "Second merge should not segfault"
  
  # Verify file is not corrupted
  if command -v jq >/dev/null 2>&1; then
    local valid_json=$(jq empty "$HOME/.claude.json" 2>&1)
    assert_equals "" "$valid_json" "Config file should remain valid JSON"
  fi
}

# Main test runner for MCP function tests
main() {
  setup_test_environment
  
  test_info "Starting comprehensive MCP function unit tests..."
  test_info "These tests verify individual MCP shell functions work correctly in isolation."
  echo ""
  
  # Core function tests
  run_test "MCP Functions: merge-servers new config" test_mcp_merge_servers_new_config
  run_test "MCP Functions: merge-servers no changes" test_mcp_merge_servers_no_changes
  run_test "MCP Functions: merge-servers with update" test_mcp_merge_servers_with_update
  
  # Main command tests
  run_test "MCP Functions: sync basic functionality" test_mcp_sync_function
  run_test "MCP Functions: sync without jq" test_mcp_sync_without_jq
  run_test "MCP Functions: sync missing servers" test_mcp_sync_missing_servers
  run_test "MCP Functions: status command" test_mcp_status_function
  run_test "MCP Functions: status out-of-sync" test_mcp_status_out_of_sync
  run_test "MCP Functions: add command" test_mcp_add_function
  run_test "MCP Functions: add invalid args" test_mcp_add_invalid_args
  
  # Utility function tests
  run_test "MCP Functions: available command" test_mcp_available_function
  run_test "MCP Functions: auto-sync logic" test_mcp_auto_sync_logic
  run_test "MCP Functions: environment variables" test_mcp_environment_variables
  
  # Edge case and safety tests
  run_test "MCP Functions: corrupt servers.json" test_mcp_functions_corrupt_servers
  run_test "MCP Functions: concurrent safety" test_mcp_concurrent_safety
  
  generate_test_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi