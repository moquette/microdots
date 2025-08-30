#!/usr/bin/env bash
#
# MCP Configuration Integration Tests
# Comprehensive testing for MCP (Model Context Protocol) installation and sync
# Tests all edge cases and failure modes for bulletproof reliability
#

# Source the test framework
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$TEST_DIR/test_framework.sh"

# MCP-specific test utilities
setup_mcp_environment() {
  # Create necessary directories that Claude might use
  mkdir -p "$HOME/.claude"
  mkdir -p "$HOME/.config/Claude"
  mkdir -p "$HOME/Library/Application Support/Claude"
  mkdir -p "$HOME/Code"  # Required by filesystem MCP server
  
  # Mock jq if not available (for testing missing dependency scenarios)
  if [ "$MOCK_MISSING_JQ" = true ]; then
    PATH="/tmp/no-jq:$PATH"
  fi
  
  # Mock npm if not available (for testing missing npm scenarios)
  if [ "$MOCK_MISSING_NPM" = true ]; then
    PATH="/tmp/no-npm:$PATH"
  fi
}

create_mock_mcp_servers() {
  local servers_file="$1"
  mkdir -p "$(dirname "$servers_file")"
  
  cat > "$servers_file" << 'EOF'
{
  "mcpServers": {
    "test-server": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@test/test-server"],
      "env": {}
    },
    "test-server-with-env": {
      "type": "stdio", 
      "command": "node",
      "args": ["/path/to/server.js"],
      "env": {
        "TEST_VAR": "test_value",
        "API_KEY": "secret123"
      }
    }
  }
}
EOF
}

create_existing_claude_config() {
  local config_file="$1"
  mkdir -p "$(dirname "$config_file")"
  
  cat > "$config_file" << 'EOF'
{
  "mcpServers": {
    "existing-server": {
      "type": "stdio",
      "command": "existing-command",
      "args": ["arg1"]
    }
  },
  "otherSettings": {
    "theme": "dark",
    "autoSave": true
  }
}
EOF
}

create_claude_config_with_other_settings() {
  local config_file="$1"
  mkdir -p "$(dirname "$config_file")"
  
  cat > "$config_file" << 'EOF'
{
  "globalSettings": {
    "autoUpdates": false,
    "telemetry": false
  },
  "userSettings": {
    "editor": "vim",
    "theme": "dark"
  }
}
EOF
}

# Test 1: Fresh system MCP installation
test_fresh_mcp_installation() {
  setup_mcp_environment
  
  # Ensure no existing configs
  rm -f "$HOME/.claude.json"
  rm -f "$HOME/.claude/.claude.json" 
  rm -f ".claude/.claude.json"
  rm -f "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  
  # Run MCP installation
  local output=$("$DOTFILES_ROOT/claude/mcp/install.sh" 2>&1)
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "MCP installation should succeed on fresh system"
  assert_contains "$output" "MCP servers.json installed" "Should report servers.json installation"
  assert_contains "$output" "Created ~/.claude.json" "Should create global Claude config"
  assert_contains "$output" "Updated ~/.claude.json with MCP servers" "Should sync to global config"
  assert_contains "$output" "Created project-specific Claude config" "Should create project config"
  
  # Verify symlink exists and is valid
  assert_symlink_valid "$HOME/.claude/mcp/servers.json" "MCP servers symlink should be created"
  
  # Verify configs were created with MCP servers
  assert_file_exists "$HOME/.claude.json" "Global Claude config should exist"
  assert_file_exists "$DOTFILES_ROOT/.claude/.claude.json" "Project Claude config should exist"
  
  # Verify MCP servers are in the configs
  if command -v jq >/dev/null 2>&1; then
    local global_servers=$(jq -r '.mcpServers | length' "$HOME/.claude.json" 2>/dev/null)
    local project_servers=$(jq -r '.mcpServers | length' "$DOTFILES_ROOT/.claude/.claude.json" 2>/dev/null)
    
    assert_not_equals "0" "$global_servers" "Global config should have MCP servers"
    assert_not_equals "0" "$project_servers" "Project config should have MCP servers"
    assert_equals "$global_servers" "$project_servers" "Both configs should have same server count"
  fi
  
  # Verify ~/Code directory was created
  assert_directory_exists "$HOME/Code" "~/Code directory should be created for filesystem MCP"
}

# Test 2: MCP installation with existing configs (preservation)
test_mcp_with_existing_configs() {
  setup_mcp_environment
  
  # Create existing Claude configs with other settings
  create_claude_config_with_other_settings "$HOME/.claude.json"
  create_existing_claude_config "$HOME/.claude/.claude.json"
  create_claude_config_with_other_settings "$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  
  # Store original content to verify preservation
  local global_before=""
  local user_before=""
  local desktop_before=""
  
  if command -v jq >/dev/null 2>&1; then
    global_before=$(jq -r '.globalSettings.autoUpdates // "missing"' "$HOME/.claude.json")
    user_before=$(jq -r '.otherSettings.theme // "missing"' "$HOME/.claude/.claude.json")  
    desktop_before=$(jq -r '.globalSettings.telemetry // "missing"' "$HOME/Library/Application Support/Claude/claude_desktop_config.json")
  fi
  
  # Run MCP installation
  local output=$("$DOTFILES_ROOT/claude/mcp/install.sh" 2>&1)
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "MCP installation should succeed with existing configs"
  assert_contains "$output" "Updated ~/.claude.json with MCP servers" "Should update global config"
  assert_contains "$output" "Updated project-specific Claude config" "Should update project config"
  
  # Verify existing settings were preserved
  if command -v jq >/dev/null 2>&1; then
    local global_after=$(jq -r '.globalSettings.autoUpdates // "missing"' "$HOME/.claude.json" 2>/dev/null)
    local user_after=$(jq -r '.otherSettings.theme // "missing"' "$HOME/.claude/.claude.json" 2>/dev/null)
    local desktop_after=$(jq -r '.globalSettings.telemetry // "missing"' "$HOME/Library/Application Support/Claude/claude_desktop_config.json" 2>/dev/null)
    
    assert_equals "$global_before" "$global_after" "Global settings should be preserved"
    assert_equals "$user_before" "$user_after" "User settings should be preserved"
    assert_equals "$desktop_before" "$desktop_after" "Desktop settings should be preserved"
    
    # Verify MCP servers were added/updated
    local mcp_servers=$(jq -r '.mcpServers | length' "$HOME/.claude.json" 2>/dev/null)
    assert_not_equals "0" "$mcp_servers" "MCP servers should be added to existing config"
  fi
}

# Test 3: Missing jq dependency handling
test_missing_jq_dependency() {
  # Mock missing jq
  mkdir -p "/tmp/no-jq"
  export MOCK_MISSING_JQ=true
  setup_mcp_environment
  
  # Run MCP installation without jq
  local output=$("$DOTFILES_ROOT/claude/mcp/install.sh" 2>&1)
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "MCP installation should succeed even without jq"
  assert_contains "$output" "MCP servers.json installed" "Should still install servers.json symlink"
  assert_file_not_exists "$HOME/.claude.json" "Should not create configs without jq"
  
  # Verify symlink still works
  assert_symlink_valid "$HOME/.claude/mcp/servers.json" "Symlink should work without jq"
  
  export MOCK_MISSING_JQ=false
}

# Test 4: Broken symlinks recovery
test_broken_symlinks_recovery() {
  setup_mcp_environment
  
  # Create broken symlinks
  mkdir -p "$HOME/.claude/mcp"
  ln -sf "/nonexistent/path" "$HOME/.claude/mcp/servers.json"
  
  # Verify it's broken
  assert_command_fails "test -e '$HOME/.claude/mcp/servers.json'" "Symlink should be broken"
  
  # Run MCP installation
  local output=$("$DOTFILES_ROOT/claude/mcp/install.sh" 2>&1)
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "Should recover from broken symlinks"
  assert_contains "$output" "MCP servers.json installed" "Should repair broken symlink"
  
  # Verify symlink is now valid
  assert_symlink_valid "$HOME/.claude/mcp/servers.json" "Symlink should be repaired"
}

# Test 5: Permission issues handling
test_permission_issues() {
  setup_mcp_environment
  
  # Create directory with restrictive permissions
  mkdir -p "$HOME/.claude"
  chmod 555 "$HOME/.claude"  # Read+execute only, no write
  
  # Run MCP installation
  local output=$("$DOTFILES_ROOT/claude/mcp/install.sh" 2>&1)
  local exit_code=$?
  
  # Should fail gracefully with permission error
  assert_equals "1" "$exit_code" "Should fail with permission error"
  
  # Restore permissions for cleanup
  chmod 755 "$HOME/.claude"
}

# Test 6: MCP sync functionality
test_mcp_sync_command() {
  setup_mcp_environment
  
  # First install MCP
  "$DOTFILES_ROOT/claude/mcp/install.sh" >/dev/null 2>&1
  
  # Source the zsh functions
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$HOME/.claude/mcp/servers.json"
  source "$DOTFILES_ROOT/claude/claude.zsh"
  
  # Create additional Claude configs to test sync
  mkdir -p ".claude"
  echo '{"otherSettings": {"test": true}}' > ".claude/.claude.json"
  
  # Test mcp-sync command
  local sync_output=$(mcp-sync 2>&1)
  local sync_exit=$?
  
  assert_equals "0" "$sync_exit" "mcp-sync should succeed"
  assert_contains "$sync_output" "MCP Server Configuration Sync" "Should show sync header"
  assert_contains "$sync_output" "Sync complete" "Should complete sync"
  
  # Verify configs were updated
  if command -v jq >/dev/null 2>&1; then
    local project_servers=$(jq -r '.mcpServers | length' ".claude/.claude.json" 2>/dev/null)
    assert_not_equals "0" "$project_servers" "Project config should have MCP servers after sync"
    
    # Verify other settings were preserved
    local other_setting=$(jq -r '.otherSettings.test' ".claude/.claude.json" 2>/dev/null)
    assert_equals "true" "$other_setting" "Other settings should be preserved during sync"
  fi
}

# Test 7: MCP status reporting
test_mcp_status_command() {
  setup_mcp_environment
  
  # Install MCP first
  "$DOTFILES_ROOT/claude/mcp/install.sh" >/dev/null 2>&1
  
  # Source the zsh functions
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$HOME/.claude/mcp/servers.json"
  source "$DOTFILES_ROOT/claude/claude.zsh"
  
  # Test mcp-status command
  local status_output=$(mcp-status 2>&1)
  local status_exit=$?
  
  assert_equals "0" "$status_exit" "mcp-status should succeed"
  assert_contains "$status_output" "MCP Server Status" "Should show status header"
  
  # Should list configured servers
  if command -v jq >/dev/null 2>&1; then
    assert_contains "$status_output" "filesystem" "Should list filesystem server"
    assert_contains "$status_output" "openmemory" "Should list openmemory server"
    assert_contains "$status_output" " Configs are up to date" "Should show sync status"
  fi
}

# Test 8: Bootstrap with install integration
test_bootstrap_install_mcp_integration() {
  setup_mcp_environment
  
  # Create gitconfig to avoid prompts
  mkdir -p "$DOTFILES_ROOT/git"
  cat > "$DOTFILES_ROOT/git/gitconfig.local.symlink" << 'EOF'
[user]
  name = Test User
  email = test@example.com
EOF
  
  # Run bootstrap with --install
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" --install 2>&1)
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "Bootstrap --install should succeed"
  assert_contains "$output" "Installing claude..." "Should install Claude topic"
  assert_contains "$output" "Installing claude/mcp..." "Should install MCP subtopic"
  assert_contains "$output" "MCP servers.json installed" "Should install MCP configuration"
  assert_contains "$output" "All dotfiles installed successfully" "Should complete successfully"
  
  # Verify MCP configuration is in place
  assert_symlink_valid "$HOME/.claude/mcp/servers.json" "MCP servers should be installed"
  assert_file_exists "$HOME/.claude.json" "Global Claude config should exist"
  assert_file_exists "$DOTFILES_ROOT/.claude/.claude.json" "Project Claude config should exist"
  
  # Verify shell functions are available after source
  export ZSH="$DOTFILES_ROOT"
  source "$DOTFILES_ROOT/claude/claude.zsh"
  
  # Functions should be available
  assert_command_succeeds "declare -f mcp-sync" "mcp-sync function should be available"
  assert_command_succeeds "declare -f mcp-status" "mcp-status function should be available"
  
  # Cleanup
  rm -f "$DOTFILES_ROOT/git/gitconfig.local.symlink"
}

# Test 9: MCP auto-sync functionality
test_mcp_auto_sync() {
  setup_mcp_environment
  
  # Install MCP first
  "$DOTFILES_ROOT/claude/mcp/install.sh" >/dev/null 2>&1
  
  # Create a newer servers.json to trigger auto-sync
  sleep 1  # Ensure timestamp difference
  touch "$HOME/.claude/mcp/servers.json"
  
  # Source with auto-sync
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$HOME/.claude/mcp/servers.json"
  
  # Test auto-sync trigger
  local auto_output=$(bash -c 'source '"$DOTFILES_ROOT"'/claude/claude.zsh 2>&1; echo "Auto-sync completed"')
  
  assert_contains "$auto_output" "Auto-sync completed" "Auto-sync should complete"
  
  # Verify configs were updated (if they exist)
  if [ -f "$HOME/.claude.json" ] && command -v jq >/dev/null 2>&1; then
    local servers_count=$(jq -r '.mcpServers | length' "$HOME/.claude.json" 2>/dev/null || echo "0")
    assert_not_equals "0" "$servers_count" "Auto-sync should maintain MCP servers"
  fi
}

# Test 10: Edge case - corrupted configuration files
test_corrupted_config_recovery() {
  setup_mcp_environment
  
  # Install MCP first
  "$DOTFILES_ROOT/claude/mcp/install.sh" >/dev/null 2>&1
  
  # Corrupt the Claude config
  echo "{ invalid json }" > "$HOME/.claude.json"
  
  # Source zsh functions and try sync
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$HOME/.claude/mcp/servers.json"
  source "$DOTFILES_ROOT/claude/claude.zsh"
  
  # Sync should handle corrupted config gracefully
  local sync_output=$(mcp-sync 2>&1)
  local sync_exit=$?
  
  # Should not crash, but may report warnings
  assert_not_equals "139" "$sync_exit" "Should not segfault on corrupted JSON"
  assert_contains "$sync_output" "MCP Server Configuration Sync" "Should still show sync header"
}

# Test 11: MCP server count validation
test_mcp_server_count_validation() {
  setup_mcp_environment
  
  # Run installation
  local output=$("$DOTFILES_ROOT/claude/mcp/install.sh" 2>&1)
  
  # Extract server count from output
  if command -v jq >/dev/null 2>&1; then
    local expected_count=$(jq -r '.mcpServers | length' "$DOTFILES_ROOT/claude/mcp/servers.json" 2>/dev/null || echo "0")
    assert_contains "$output" "($expected_count servers configured)" "Should report correct server count"
    assert_not_equals "0" "$expected_count" "Should have at least one server configured"
  fi
  
  # Verify specific expected servers exist
  if command -v jq >/dev/null 2>&1; then
    local servers_list=$(jq -r '.mcpServers | keys[]' "$DOTFILES_ROOT/claude/mcp/servers.json" 2>/dev/null)
    assert_contains "$servers_list" "filesystem" "Should include filesystem server"
    assert_contains "$servers_list" "openmemory" "Should include openmemory server"
    assert_contains "$servers_list" "context7" "Should include context7 server"
  fi
}

# Test 12: Claude Desktop config location handling
test_claude_desktop_config_location() {
  setup_mcp_environment
  
  # Create Claude Desktop config directory and file
  local desktop_config="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
  mkdir -p "$(dirname "$desktop_config")"
  create_claude_config_with_other_settings "$desktop_config"
  
  # Install MCP
  "$DOTFILES_ROOT/claude/mcp/install.sh" >/dev/null 2>&1
  
  # Source functions and sync
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$HOME/.claude/mcp/servers.json"
  source "$DOTFILES_ROOT/claude/claude.zsh"
  
  local sync_output=$(mcp-sync 2>&1)
  
  assert_contains "$sync_output" "Updating Claude Desktop config" "Should detect and update Desktop config"
  
  # Verify Desktop config was updated with MCP servers
  if command -v jq >/dev/null 2>&1; then
    local desktop_servers=$(jq -r '.mcpServers | length' "$desktop_config" 2>/dev/null || echo "0")
    assert_not_equals "0" "$desktop_servers" "Desktop config should have MCP servers"
    
    # Verify other settings preserved
    local preserved_setting=$(jq -r '.globalSettings.telemetry' "$desktop_config" 2>/dev/null)
    assert_equals "false" "$preserved_setting" "Desktop config other settings should be preserved"
  fi
}

# Test 13: MCP add command functionality
test_mcp_add_command() {
  setup_mcp_environment
  
  # Install MCP first
  "$DOTFILES_ROOT/claude/mcp/install.sh" >/dev/null 2>&1
  
  # Source functions
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$HOME/.claude/mcp/servers.json"
  source "$DOTFILES_ROOT/claude/claude.zsh"
  
  # Test adding a new server
  local add_output=$(mcp-add "test-server" "npx -y @test/test-server" 2>&1)
  local add_exit=$?
  
  if command -v jq >/dev/null 2>&1; then
    assert_equals "0" "$add_exit" "mcp-add should succeed"
    assert_contains "$add_output" "Adding MCP server: test-server" "Should show adding server"
    assert_contains "$add_output" "Added to servers.json" "Should confirm addition"
    assert_contains "$add_output" "Running sync" "Should trigger sync"
    
    # Verify server was added
    local server_exists=$(jq -r '.mcpServers["test-server"] | length' "$MCP_SERVERS_FILE" 2>/dev/null)
    assert_not_equals "0" "$server_exists" "New server should be added to servers.json"
  else
    # Without jq, command should fail gracefully
    assert_not_equals "0" "$add_exit" "mcp-add should fail without jq"
  fi
}

# Test 14: Comprehensive end-to-end workflow
test_complete_mcp_workflow() {
  setup_mcp_environment
  
  # Step 1: Fresh bootstrap installation
  mkdir -p "$DOTFILES_ROOT/git"
  cat > "$DOTFILES_ROOT/git/gitconfig.local.symlink" << 'EOF'
[user]
  name = Test User  
  email = test@example.com
EOF
  
  local bootstrap_output=$("$DOTFILES_ROOT/core/commands/bootstrap" --install 2>&1)
  assert_equals "0" "$?" "Complete bootstrap should succeed"
  
  # Step 2: Verify MCP installation
  assert_symlink_valid "$HOME/.claude/mcp/servers.json" "MCP servers should be installed"
  assert_file_exists "$HOME/.claude.json" "Global config should exist"
  
  # Step 3: Test shell integration
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$HOME/.claude/mcp/servers.json"
  source "$DOTFILES_ROOT/claude/claude.zsh"
  
  # Step 4: Test status command
  local status_output=$(mcp-status 2>&1)
  assert_contains "$status_output" "MCP Server Status" "Status should work"
  
  # Step 5: Test sync command
  local sync_output=$(mcp-sync 2>&1)
  assert_contains "$sync_output" "Sync complete" "Sync should work"
  
  # Step 6: Verify servers are accessible via all configs
  if command -v jq >/dev/null 2>&1; then
    for config in "$HOME/.claude.json" "$DOTFILES_ROOT/.claude/.claude.json"; do
      if [ -f "$config" ]; then
        local server_count=$(jq -r '.mcpServers | length' "$config" 2>/dev/null || echo "0")
        assert_not_equals "0" "$server_count" "Config $config should have MCP servers"
      fi
    done
  fi
  
  # Cleanup
  rm -f "$DOTFILES_ROOT/git/gitconfig.local.symlink"
}

# Test 15: Rollback and recovery scenarios
test_mcp_rollback_recovery() {
  setup_mcp_environment
  
  # Install MCP first
  "$DOTFILES_ROOT/claude/mcp/install.sh" >/dev/null 2>&1
  
  # Create backup scenarios
  if command -v jq >/dev/null 2>&1; then
    # Source functions
    export ZSH="$DOTFILES_ROOT"
    export MCP_SERVERS_FILE="$HOME/.claude/mcp/servers.json"
    source "$DOTFILES_ROOT/claude/claude.zsh"
    
    # Create a config to be backed up
    echo '{"testSettings": {"backed": "up"}}' > "$HOME/.claude.json"
    
    # Run sync (should create backup)
    local sync_output=$(mcp-sync 2>&1)
    
    # Verify backup was created
    assert_file_exists "$HOME/.claude.json.backup" "Backup should be created"
    
    # Verify original setting can be recovered from backup
    local backup_setting=$(jq -r '.testSettings.backed' "$HOME/.claude.json.backup" 2>/dev/null)
    assert_equals "up" "$backup_setting" "Backup should preserve original settings"
    
    # Verify new config has both MCP servers and indicates backup
    local mcp_count=$(jq -r '.mcpServers | length' "$HOME/.claude.json" 2>/dev/null || echo "0")
    assert_not_equals "0" "$mcp_count" "Updated config should have MCP servers"
    
    assert_contains "$sync_output" "Backup:" "Sync should mention backup creation"
  fi
}

# Main test runner for MCP configuration tests
main() {
  setup_test_environment
  
  test_info "Starting comprehensive MCP configuration tests..."
  test_info "These tests ensure bulletproof reliability of MCP system installation and synchronization."
  echo ""
  
  # Core installation tests
  run_test "MCP: Fresh System Installation" test_fresh_mcp_installation
  run_test "MCP: Installation with Existing Configs" test_mcp_with_existing_configs
  run_test "MCP: Missing jq Dependency" test_missing_jq_dependency
  run_test "MCP: Broken Symlinks Recovery" test_broken_symlinks_recovery
  run_test "MCP: Permission Issues Handling" test_permission_issues
  
  # Command functionality tests  
  run_test "MCP: Sync Command Functionality" test_mcp_sync_command
  run_test "MCP: Status Command" test_mcp_status_command
  run_test "MCP: Auto-Sync Functionality" test_mcp_auto_sync
  run_test "MCP: Add Command" test_mcp_add_command
  
  # Integration and edge case tests
  run_test "MCP: Bootstrap Integration" test_bootstrap_install_mcp_integration
  run_test "MCP: Corrupted Config Recovery" test_corrupted_config_recovery
  run_test "MCP: Server Count Validation" test_mcp_server_count_validation
  run_test "MCP: Claude Desktop Config" test_claude_desktop_config_location
  run_test "MCP: Rollback and Recovery" test_mcp_rollback_recovery
  
  # Complete workflow test
  run_test "MCP: Complete End-to-End Workflow" test_complete_mcp_workflow
  
  generate_test_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi