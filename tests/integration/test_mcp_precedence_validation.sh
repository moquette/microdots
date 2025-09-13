#!/usr/bin/env bash
#
# MCP Script Precedence Validation Tests
# Specifically tests the fixed MCP scripts in NewDotlocal that implement precedence
# 
# Tests the exact behavior of the fixed scripts:
# - /Volumes/My Shared Files/NewDotlocal/claude/mcp/mcp-setup  
# - /Volumes/My Shared Files/NewDotlocal/claude/mcp/mcp-status
#
# These scripts implement the precedence pattern and graceful degradation
#

# Source the test framework
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$TEST_DIR/test_framework.sh"

# Location of the fixed MCP scripts
FIXED_MCP_DIR="/Volumes/My Shared Files/NewDotlocal/claude/mcp"
FIXED_MCP_SETUP="$FIXED_MCP_DIR/mcp-setup"
FIXED_MCP_STATUS="$FIXED_MCP_DIR/mcp-status"

# Test environment setup
setup_mcp_precedence_environment() {
    export ZSH="$DOTFILES_ROOT"
    export TEST_LOCAL_EXTERNAL="/tmp/test_local_mcp_$$"
    mkdir -p "$TEST_LOCAL_EXTERNAL"
    
    # Ensure we have clean test state
    rm -rf "$DOTFILES_ROOT/claude"
    rm -rf "$DOTFILES_ROOT/.local"
    
    test_info "MCP Precedence Test Environment:"
    test_info "  ZSH: $ZSH"
    test_info "  TEST_LOCAL_EXTERNAL: $TEST_LOCAL_EXTERNAL"
    test_info "  FIXED_MCP_SETUP: $FIXED_MCP_SETUP"
    test_info "  FIXED_MCP_STATUS: $FIXED_MCP_STATUS"
}

create_public_mcp_config() {
    local public_dir="$DOTFILES_ROOT/claude/mcp"
    mkdir -p "$public_dir"
    
    cat > "$public_dir/servers.json" << 'EOF'
{
  "mcpServers": {
    "public-filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic/filesystem-mcp-server", "/tmp"],
      "type": "stdio"
    },
    "public-context": {
      "command": "npx",
      "args": ["-y", "@anthropic/context7-mcp-server"],
      "type": "stdio"
    }
  }
}
EOF
    
    success "Created public MCP configuration"
}

create_local_mcp_config() {
    local local_dir="$TEST_LOCAL_EXTERNAL/claude/mcp"
    mkdir -p "$local_dir"
    
    cat > "$local_dir/servers.json" << 'EOF'
{
  "mcpServers": {
    "local-filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic/filesystem-mcp-server", "\$HOME/Code"],
      "type": "stdio"
    },
    "local-memory": {
      "command": "npx",
      "args": ["-y", "@anthropic/memory-mcp-server"],
      "type": "stdio"
    },
    "local-exclusive": {
      "command": "echo",
      "args": ["local-only-server"],
      "type": "stdio"
    }
  }
}
EOF
    
    success "Created local MCP configuration"
}

cleanup_mcp_test() {
    rm -rf "$DOTFILES_ROOT/claude"
    rm -rf "$DOTFILES_ROOT/.local"  
    rm -rf "$TEST_LOCAL_EXTERNAL"
    rm -f "$HOME/.claude.json"
    rm -f "$HOME/.claude.json.backup"
}

# Test 1: Fixed mcp-setup with PUBLIC only configuration
test_fixed_mcp_setup_public_only() {
    setup_mcp_precedence_environment
    create_public_mcp_config
    
    # Verify fixed scripts exist
    assert_file_exists "$FIXED_MCP_SETUP" "Fixed mcp-setup script should exist"
    assert_executable "$FIXED_MCP_SETUP" "Fixed mcp-setup should be executable"
    
    # Run the fixed mcp-setup script with public only
    local setup_output
    setup_output=$("$FIXED_MCP_SETUP" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Fixed mcp-setup should succeed with public only"
    assert_contains "$setup_output" "Using public MCP configuration" "Should indicate public config"
    assert_contains "$setup_output" "Setting up MCP servers for Claude Code" "Should show setup process"
    
    if command -v jq >/dev/null 2>&1; then
        assert_contains "$setup_output" "MCP servers configured successfully" "Should confirm success"
        assert_file_exists "$HOME/.claude.json" "Should create Claude config"
        
        # Verify correct servers configured
        local servers
        servers=$(jq -r '.mcpServers | keys[]' "$HOME/.claude.json" 2>/dev/null)
        assert_contains "$servers" "public-filesystem" "Should configure public servers"
        assert_contains "$servers" "public-context" "Should configure public servers"
    else
        test_warning "jq not available - skipping JSON verification"
    fi
    
    cleanup_mcp_test
}

# Test 2: Fixed mcp-setup with LOCAL only configuration
test_fixed_mcp_setup_local_only() {
    setup_mcp_precedence_environment
    create_local_mcp_config
    
    # Create .local symlink
    ln -sfn "$TEST_LOCAL_EXTERNAL" "$DOTFILES_ROOT/.local"
    
    # Run the fixed mcp-setup script with local only
    local setup_output
    setup_output=$("$FIXED_MCP_SETUP" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Fixed mcp-setup should succeed with local only"
    assert_contains "$setup_output" "Using local MCP configuration" "Should indicate local config"
    
    if command -v jq >/dev/null 2>&1; then
        assert_file_exists "$HOME/.claude.json" "Should create Claude config"
        
        # Verify correct LOCAL servers configured
        local servers
        servers=$(jq -r '.mcpServers | keys[]' "$HOME/.claude.json" 2>/dev/null)
        assert_contains "$servers" "local-filesystem" "Should configure local servers"
        assert_contains "$servers" "local-memory" "Should configure local servers"
        assert_contains "$servers" "local-exclusive" "Should configure local-only servers"
    fi
    
    cleanup_mcp_test
}

# Test 3: Fixed mcp-setup with BOTH - Local should win
test_fixed_mcp_setup_local_precedence() {
    setup_mcp_precedence_environment
    create_public_mcp_config
    create_local_mcp_config
    
    # Create .local symlink
    ln -sfn "$TEST_LOCAL_EXTERNAL" "$DOTFILES_ROOT/.local"
    
    # Run the fixed mcp-setup script with both configs
    local setup_output
    setup_output=$("$FIXED_MCP_SETUP" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Fixed mcp-setup should succeed with both configs"
    assert_contains "$setup_output" "Using local MCP configuration" "Should prefer LOCAL over public"
    
    if command -v jq >/dev/null 2>&1; then
        assert_file_exists "$HOME/.claude.json" "Should create Claude config"
        
        # Verify LOCAL servers configured, NOT public
        local servers
        servers=$(jq -r '.mcpServers | keys[]' "$HOME/.claude.json" 2>/dev/null)
        assert_contains "$servers" "local-filesystem" "Should use local servers"
        assert_contains "$servers" "local-exclusive" "Should include local-only servers"
        
        # Verify public servers are NOT configured
        local public_count
        public_count=$(echo "$servers" | grep -c "public-" || echo "0")
        assert_equals "0" "$public_count" "Should not configure public servers when local exists"
    fi
    
    cleanup_mcp_test
}

# Test 4: Fixed mcp-setup with NEITHER - Graceful degradation
test_fixed_mcp_setup_neither_exists() {
    setup_mcp_precedence_environment
    
    # Ensure neither local nor public exists
    rm -rf "$DOTFILES_ROOT/claude"
    rm -rf "$DOTFILES_ROOT/.local"
    rm -rf "$TEST_LOCAL_EXTERNAL"
    
    # Run the fixed mcp-setup script with no configs
    local setup_output
    setup_output=$("$FIXED_MCP_SETUP" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Should gracefully handle neither existing"
    assert_contains "$setup_output" "No MCP servers.json found" "Should report no config found"
    assert_contains "$setup_output" "MCP setup skipped - this is not an error" "Should indicate normal behavior"
    
    # Should NOT create Claude config when no servers exist
    assert_file_not_exists "$HOME/.claude.json" "Should not create config without servers"
    
    cleanup_mcp_test
}

# Test 5: Fixed mcp-status with PUBLIC only configuration  
test_fixed_mcp_status_public_only() {
    setup_mcp_precedence_environment
    create_public_mcp_config
    
    # Verify fixed mcp-status exists
    assert_file_exists "$FIXED_MCP_STATUS" "Fixed mcp-status script should exist"
    assert_executable "$FIXED_MCP_STATUS" "Fixed mcp-status should be executable"
    
    # Run the fixed mcp-status script
    local status_output
    status_output=$("$FIXED_MCP_STATUS" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Fixed mcp-status should succeed with public only"
    assert_contains "$status_output" "MCP Server Status for Claude Code" "Should show status header"
    assert_contains "$status_output" "Using PUBLIC:" "Should indicate public configuration"
    assert_contains "$status_output" "$ZSH/claude/mcp/servers.json" "Should show public path"
    
    if command -v jq >/dev/null 2>&1; then
        assert_contains "$status_output" "Available servers:" "Should list available servers"
        assert_contains "$status_output" "public-filesystem" "Should show public servers"
        assert_contains "$status_output" "public-context" "Should show public servers"
    fi
    
    cleanup_mcp_test
}

# Test 6: Fixed mcp-status with LOCAL only configuration
test_fixed_mcp_status_local_only() {
    setup_mcp_precedence_environment
    create_local_mcp_config
    
    # Create .local symlink
    ln -sfn "$TEST_LOCAL_EXTERNAL" "$DOTFILES_ROOT/.local"
    
    # Run the fixed mcp-status script
    local status_output
    status_output=$("$FIXED_MCP_STATUS" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Fixed mcp-status should succeed with local only"
    assert_contains "$status_output" "Using LOCAL:" "Should indicate local configuration"
    assert_contains "$status_output" "$ZSH/.local/claude/mcp/servers.json" "Should show local path"
    
    if command -v jq >/dev/null 2>&1; then
        assert_contains "$status_output" "local-filesystem" "Should show local servers"
        assert_contains "$status_output" "local-exclusive" "Should show local-only servers"
    fi
    
    cleanup_mcp_test
}

# Test 7: Fixed mcp-status with BOTH - Local should win
test_fixed_mcp_status_local_precedence() {
    setup_mcp_precedence_environment
    create_public_mcp_config
    create_local_mcp_config
    
    # Create .local symlink
    ln -sfn "$TEST_LOCAL_EXTERNAL" "$DOTFILES_ROOT/.local"
    
    # Run the fixed mcp-status script
    local status_output
    status_output=$("$FIXED_MCP_STATUS" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Fixed mcp-status should succeed with both configs"
    assert_contains "$status_output" "Using LOCAL:" "Should prefer LOCAL over public"
    assert_contains "$status_output" "$ZSH/.local/claude/mcp/servers.json" "Should show local path"
    
    if command -v jq >/dev/null 2>&1; then
        # Should show local servers, not public
        assert_contains "$status_output" "local-filesystem" "Should show local servers"
        assert_contains "$status_output" "local-exclusive" "Should show local-only servers"
        
        # Should NOT show public servers when local exists
        local public_count
        public_count=$(echo "$status_output" | grep -c "public-filesystem" || echo "0")
        assert_equals "0" "$public_count" "Should not show public servers when local wins"
    fi
    
    cleanup_mcp_test
}

# Test 8: Fixed mcp-status with NEITHER - Graceful degradation
test_fixed_mcp_status_neither_exists() {
    setup_mcp_precedence_environment
    
    # Ensure neither exists
    rm -rf "$DOTFILES_ROOT/claude"
    rm -rf "$DOTFILES_ROOT/.local"
    rm -rf "$TEST_LOCAL_EXTERNAL"
    
    # Run the fixed mcp-status script
    local status_output
    status_output=$("$FIXED_MCP_STATUS" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Should handle neither existing gracefully"
    assert_contains "$status_output" "No servers.json found in local or public" "Should report none found"
    assert_contains "$status_output" "Checked: $ZSH/.local/claude/mcp/" "Should show local check"
    assert_contains "$status_output" "Checked: $ZSH/claude/mcp/" "Should show public check"
    
    cleanup_mcp_test
}

# Test 9: Environment variable usage (no hardcoded paths)
test_fixed_scripts_environment_variables() {
    setup_mcp_precedence_environment
    create_public_mcp_config
    
    # Test with custom ZSH environment
    local custom_dotfiles="/tmp/custom_dotfiles_$$"
    mkdir -p "$custom_dotfiles/claude/mcp"
    
    cat > "$custom_dotfiles/claude/mcp/servers.json" << 'EOF'
{
  "mcpServers": {
    "custom-env-server": {
      "command": "echo",
      "args": ["custom-environment"],
      "type": "stdio"
    }
  }
}
EOF
    
    # Test mcp-status with custom environment
    local custom_output
    custom_output=$(ZSH="$custom_dotfiles" "$FIXED_MCP_STATUS" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Should work with custom ZSH environment"
    assert_contains "$custom_output" "$custom_dotfiles/claude/mcp/servers.json" "Should use ZSH variable"
    
    if command -v jq >/dev/null 2>&1; then
        assert_contains "$custom_output" "custom-env-server" "Should read from custom location"
    fi
    
    # Clean up
    rm -rf "$custom_dotfiles"
    cleanup_mcp_test
}

# Test 10: Missing jq dependency handling
test_fixed_scripts_missing_jq() {
    setup_mcp_precedence_environment
    create_public_mcp_config
    
    # Mock missing jq by manipulating PATH
    local original_path="$PATH"
    export PATH="/tmp/no-jq-path"
    mkdir -p "/tmp/no-jq-path"
    
    # Test mcp-setup without jq
    local setup_output
    setup_output=$("$FIXED_MCP_SETUP" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Should handle missing jq gracefully"
    assert_contains "$setup_output" "Using public MCP configuration" "Should still find config"
    assert_contains "$setup_output" "Warning: jq is required" "Should warn about missing jq"
    assert_contains "$setup_output" "MCP setup skipped" "Should skip gracefully"
    
    # Test mcp-status without jq
    local status_output
    status_output=$("$FIXED_MCP_STATUS" 2>&1)
    exit_code=$?
    
    assert_equals "0" "$exit_code" "mcp-status should work without jq"
    assert_contains "$status_output" "Using PUBLIC:" "Should still show config location"
    assert_contains "$status_output" "(install jq to see server details)" "Should suggest jq installation"
    
    # Restore PATH
    export PATH="$original_path"
    cleanup_mcp_test
}

# Test 11: Permission and error handling
test_fixed_scripts_permission_handling() {
    setup_mcp_precedence_environment
    create_public_mcp_config
    
    # Create restricted Claude directory
    mkdir -p "$HOME/.claude"
    chmod 000 "$HOME/.claude"
    
    # Test mcp-setup with permission issues
    local setup_output
    setup_output=$("$FIXED_MCP_SETUP" 2>&1 || true)
    local exit_code=$?
    
    # Should fail but not crash
    assert_not_equals "0" "$exit_code" "Should fail with permission error"
    assert_not_equals "139" "$exit_code" "Should not segfault"
    
    # Restore permissions
    chmod 755 "$HOME/.claude"
    cleanup_mcp_test
}

# Test 12: Complete workflow with fixed scripts
test_fixed_scripts_complete_workflow() {
    setup_mcp_precedence_environment
    
    # Step 1: Start with public only
    test_info "Step 1: Public only setup"
    create_public_mcp_config
    
    local public_status
    public_status=$("$FIXED_MCP_STATUS" 2>&1)
    assert_contains "$public_status" "Using PUBLIC:" "Should start with public"
    
    if command -v jq >/dev/null 2>&1; then
        local public_setup
        public_setup=$("$FIXED_MCP_SETUP" 2>&1)
        assert_contains "$public_setup" "MCP servers configured successfully" "Should configure public"
        assert_file_exists "$HOME/.claude.json" "Should create config"
    fi
    
    # Step 2: Add local (should switch precedence)
    test_info "Step 2: Adding local configuration"
    create_local_mcp_config
    ln -sfn "$TEST_LOCAL_EXTERNAL" "$DOTFILES_ROOT/.local"
    
    local local_status
    local_status=$("$FIXED_MCP_STATUS" 2>&1)
    assert_contains "$local_status" "Using LOCAL:" "Should switch to local"
    
    if command -v jq >/dev/null 2>&1; then
        # Clean previous config and setup with local
        rm -f "$HOME/.claude.json"
        local local_setup
        local_setup=$("$FIXED_MCP_SETUP" 2>&1)
        assert_contains "$local_setup" "Using local MCP configuration" "Should use local"
        
        # Verify local servers configured
        local servers
        servers=$(jq -r '.mcpServers | keys[]' "$HOME/.claude.json" 2>/dev/null)
        assert_contains "$servers" "local-exclusive" "Should configure local-only servers"
    fi
    
    # Step 3: Remove local (should fall back)
    test_info "Step 3: Removing local - should fallback"
    rm -f "$DOTFILES_ROOT/.local"
    rm -rf "$TEST_LOCAL_EXTERNAL"
    
    local fallback_status
    fallback_status=$("$FIXED_MCP_STATUS" 2>&1)
    assert_contains "$fallback_status" "Using PUBLIC:" "Should fallback to public"
    
    # Step 4: Remove everything (should gracefully degrade)
    test_info "Step 4: Complete removal - graceful degradation"
    rm -rf "$DOTFILES_ROOT/claude"
    
    local empty_status
    empty_status=$("$FIXED_MCP_STATUS" 2>&1)
    assert_contains "$empty_status" "No servers.json found" "Should report none found"
    
    local empty_setup
    empty_setup=$("$FIXED_MCP_SETUP" 2>&1)
    assert_contains "$empty_setup" "MCP setup skipped - this is not an error" "Should skip gracefully"
    
    cleanup_mcp_test
}

# Main test runner
main() {
    setup_test_environment
    
    test_info "=' MCP SCRIPT PRECEDENCE VALIDATION TESTS"
    test_info "Testing the FIXED MCP scripts that implement precedence correctly"
    test_info "Location: $FIXED_MCP_DIR"
    echo ""
    
    # Verify fixed scripts exist before running tests
    if [[ ! -f "$FIXED_MCP_SETUP" ]]; then
        test_error "Fixed mcp-setup script not found at $FIXED_MCP_SETUP"
        exit 1
    fi
    
    if [[ ! -f "$FIXED_MCP_STATUS" ]]; then
        test_error "Fixed mcp-status script not found at $FIXED_MCP_STATUS"  
        exit 1
    fi
    
    test_success "Found fixed MCP scripts - proceeding with validation"
    echo ""
    
    # Core precedence tests for mcp-setup
    run_test "Fixed mcp-setup: Public Only" test_fixed_mcp_setup_public_only
    run_test "Fixed mcp-setup: Local Only" test_fixed_mcp_setup_local_only
    run_test "Fixed mcp-setup: Local Wins Over Public" test_fixed_mcp_setup_local_precedence
    run_test "Fixed mcp-setup: Neither Exists - Graceful" test_fixed_mcp_setup_neither_exists
    
    # Core precedence tests for mcp-status
    run_test "Fixed mcp-status: Public Only" test_fixed_mcp_status_public_only
    run_test "Fixed mcp-status: Local Only" test_fixed_mcp_status_local_only
    run_test "Fixed mcp-status: Local Wins Over Public" test_fixed_mcp_status_local_precedence
    run_test "Fixed mcp-status: Neither Exists - Graceful" test_fixed_mcp_status_neither_exists
    
    # Architecture and resilience tests
    run_test "Fixed Scripts: Environment Variable Usage" test_fixed_scripts_environment_variables
    run_test "Fixed Scripts: Missing jq Handling" test_fixed_scripts_missing_jq
    run_test "Fixed Scripts: Permission Error Handling" test_fixed_scripts_permission_handling
    
    # Complete workflow test
    run_test "Fixed Scripts: Complete Workflow" test_fixed_scripts_complete_workflow
    
    generate_test_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi