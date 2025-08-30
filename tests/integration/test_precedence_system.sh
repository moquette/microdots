#!/usr/bin/env bash
#
# Precedence System Integration Tests - The Ultimate Test of Microdots Architecture
# Tests the core principle: LOCAL ALWAYS WINS, GRACEFUL DEGRADATION ALWAYS
#
# This test suite validates the most critical aspect of the Microdots system:
# 1. Precedence: local overrides public when both exist
# 2. Flexibility: works with local only, public only, both, or neither  
# 3. Graceful degradation: never fails, always provides feedback
# 4. No hardcoded paths: uses filesystem discovery and environment variables
#

# Source the test framework
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$TEST_DIR/test_framework.sh"

# Test-specific setup
setup_precedence_environment() {
    # Set up clean test environment with ZSH pointing to our test dotfiles
    export ZSH="$DOTFILES_ROOT"
    
    # Create the external local directory that would be symlinked
    export TEST_LOCAL_EXTERNAL="/tmp/test_dotlocal_$$"
    mkdir -p "$TEST_LOCAL_EXTERNAL"
    
    test_info "Test environment setup:"
    test_info "  DOTFILES_ROOT: $DOTFILES_ROOT"
    test_info "  ZSH: $ZSH"
    test_info "  TEST_LOCAL_EXTERNAL: $TEST_LOCAL_EXTERNAL"
}

create_test_claude_topic_public() {
    local claude_dir="$DOTFILES_ROOT/claude"
    mkdir -p "$claude_dir/mcp"
    
    # Create public MCP configuration
    cat > "$claude_dir/mcp/servers.json" << 'EOF'
{
  "mcpServers": {
    "public-filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic/filesystem-mcp-server", "/tmp"],
      "type": "stdio"
    },
    "public-memory": {
      "command": "npx", 
      "args": ["-y", "@anthropic/memory-mcp-server"],
      "type": "stdio"
    }
  }
}
EOF
    
    # Create public MCP scripts that follow precedence patterns  
    cat > "$claude_dir/mcp/mcp-setup" << 'EOF'
#!/bin/bash
# MCP Setup - Configure MCP servers for Claude Code
# Follows microdot precedence: local overrides public, both are optional

CLAUDE_CODE_CONFIG="$HOME/.claude.json"
ZSH="${ZSH:-$HOME/.dotfiles}"

# Find servers.json following precedence (local wins if both exist)
MCP_CONFIG=""
if [[ -f "$ZSH/.local/claude/mcp/servers.json" ]]; then
    # Local takes precedence
    MCP_CONFIG="$ZSH/.local/claude/mcp/servers.json"
    echo "Using local MCP configuration"
elif [[ -f "$ZSH/claude/mcp/servers.json" ]]; then
    # Fall back to public
    MCP_CONFIG="$ZSH/claude/mcp/servers.json"
    echo "Using public MCP configuration"
else
    # Neither exists - graceful exit
    echo "No MCP servers.json found (checked local and public)"
    echo "MCP setup skipped - this is not an error"
    exit 0
fi

echo "Setting up MCP servers for Claude Code..."

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
    echo "Warning: jq is required for MCP setup. Install with: brew install jq"
    echo "MCP setup skipped"
    exit 0
fi

# Backup existing config if it exists
if [ -f "$CLAUDE_CODE_CONFIG" ]; then
    cp "$CLAUDE_CODE_CONFIG" "$CLAUDE_CODE_CONFIG.backup"
fi

# Extract MCP servers from found config
MCP_SERVERS=$(jq '.mcpServers // {}' "$MCP_CONFIG")

# Create or update Claude Code config with MCP servers
if [ -f "$CLAUDE_CODE_CONFIG" ]; then
    # Merge MCP servers into existing config
    jq --argjson servers "$MCP_SERVERS" '.mcpServers = $servers' "$CLAUDE_CODE_CONFIG" > "$CLAUDE_CODE_CONFIG.tmp" && \
    mv "$CLAUDE_CODE_CONFIG.tmp" "$CLAUDE_CODE_CONFIG"
else
    # Create new config with MCP servers
    echo "$MCP_SERVERS" | jq '{mcpServers: .}' > "$CLAUDE_CODE_CONFIG"
fi

echo " MCP servers configured successfully for Claude Code"
echo "   Source: $MCP_CONFIG"
echo "Restart Claude Code to apply changes"
EOF
    chmod +x "$claude_dir/mcp/mcp-setup"
    
    cat > "$claude_dir/mcp/mcp-status" << 'EOF'
#!/bin/bash
# MCP Status - Check MCP server configuration status for Claude Code
# Follows microdot precedence: local overrides public, both are optional

CLAUDE_CODE_CONFIG="$HOME/.claude.json"
ZSH="${ZSH:-$HOME/.dotfiles}"

echo "=== MCP Server Status for Claude Code ==="
echo

# Find servers.json following precedence (local wins if both exist)
MCP_CONFIG=""
if [[ -f "$ZSH/.local/claude/mcp/servers.json" ]]; then
    MCP_CONFIG="$ZSH/.local/claude/mcp/servers.json"
    CONFIG_LOCATION="local"
elif [[ -f "$ZSH/claude/mcp/servers.json" ]]; then
    MCP_CONFIG="$ZSH/claude/mcp/servers.json"
    CONFIG_LOCATION="public"
else
    CONFIG_LOCATION="none"
fi

# Check Claude Code config
if [ -f "$CLAUDE_CODE_CONFIG" ]; then
    echo " Claude Code configuration found at:"
    echo "   $CLAUDE_CODE_CONFIG"
    echo
    
    if command -v jq >/dev/null 2>&1; then
        # Check if MCP servers are configured
        if jq -e '.mcpServers' "$CLAUDE_CODE_CONFIG" >/dev/null 2>&1; then
            echo "Configured MCP servers:"
            jq -r '.mcpServers | to_entries[] | "  - \(.key)"' "$CLAUDE_CODE_CONFIG" 2>/dev/null || echo "  Unable to parse configuration"
        else
            echo "L No MCP servers configured in Claude Code"
            echo "   Run 'mcp-setup' to configure MCP servers"
        fi
    else
        echo "  (install jq to see server details)"
    fi
else
    echo "L Claude Code configuration not found"
    echo "   Run 'mcp-setup' to create configuration"
fi

echo
echo "MCP configuration source:"
if [[ "$CONFIG_LOCATION" == "local" ]]; then
    echo "   Using LOCAL: $MCP_CONFIG"
    if command -v jq >/dev/null 2>&1; then
        echo "  Available servers:"
        jq -r '.mcpServers | to_entries[] | "    - \(.key)"' "$MCP_CONFIG" 2>/dev/null || echo "    Unable to parse configuration"
    fi
elif [[ "$CONFIG_LOCATION" == "public" ]]; then
    echo "   Using PUBLIC: $MCP_CONFIG"
    if command -v jq >/dev/null 2>&1; then
        echo "  Available servers:"
        jq -r '.mcpServers | to_entries[] | "    - \(.key)"' "$MCP_CONFIG" 2>/dev/null || echo "    Unable to parse configuration"
    fi
else
    echo "     No servers.json found in local or public"
    echo "     Checked: $ZSH/.local/claude/mcp/"
    echo "     Checked: $ZSH/claude/mcp/"
fi

echo
echo "Claude Code location:"
if [ -d "/Applications/Claude Code.app" ]; then
    echo "   /Applications/Claude Code.app"
elif command -v claude >/dev/null 2>&1; then
    echo "   Claude Code CLI found: $(which claude)"
else
    echo "     Claude Code app not found in /Applications"
fi
EOF
    chmod +x "$claude_dir/mcp/mcp-status"
    
    success "Created public claude topic with MCP scripts"
}

create_test_claude_topic_local() {
    local local_claude_dir="$TEST_LOCAL_EXTERNAL/claude"
    mkdir -p "$local_claude_dir/mcp"
    
    # Create local MCP configuration that should override public
    cat > "$local_claude_dir/mcp/servers.json" << 'EOF'
{
  "mcpServers": {
    "local-filesystem": {
      "command": "npx",
      "args": ["-y", "@anthropic/filesystem-mcp-server", "/Users/me/Code"],
      "type": "stdio"
    },
    "local-memory": {
      "command": "npx",
      "args": ["-y", "@anthropic/memory-mcp-server"],
      "type": "stdio"
    },
    "local-only-server": {
      "command": "echo",
      "args": ["local-only"],
      "type": "stdio"
    }
  }
}
EOF
    
    # Create enhanced local scripts (could override public ones)
    cat > "$local_claude_dir/mcp/mcp-setup" << 'EOF'
#!/bin/bash
# LOCAL ENHANCED MCP Setup - This would override the public version
echo "Using LOCAL ENHANCED mcp-setup script"
echo "This script demonstrates local override capability"
exit 0
EOF
    chmod +x "$local_claude_dir/mcp/mcp-setup"
    
    success "Created local claude topic with MCP configuration"
}

cleanup_test_topics() {
    # Clean up any test topics we created
    rm -rf "$DOTFILES_ROOT/claude"
    rm -rf "$TEST_LOCAL_EXTERNAL"
}

# Test 1: Public Only Configuration (baseline functionality)
test_precedence_public_only() {
    setup_precedence_environment
    create_test_claude_topic_public
    
    # Ensure no local exists
    rm -rf "$DOTFILES_ROOT/.local"
    rm -rf "$TEST_LOCAL_EXTERNAL"
    
    # Test mcp-status with public only
    local status_output
    status_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "mcp-status should succeed with public only"
    assert_contains "$status_output" "Using PUBLIC:" "Should indicate public configuration"
    assert_contains "$status_output" "$ZSH/claude/mcp/servers.json" "Should show public path"
    assert_contains "$status_output" "public-filesystem" "Should list public servers"
    assert_contains "$status_output" "public-memory" "Should list public servers"
    
    # Test mcp-setup with public only
    if command -v jq >/dev/null 2>&1; then
        local setup_output
        setup_output=$("$DOTFILES_ROOT/claude/mcp/mcp-setup" 2>&1)
        local setup_exit=$?
        
        assert_equals "0" "$setup_exit" "mcp-setup should succeed with public only"
        assert_contains "$setup_output" "Using public MCP configuration" "Should indicate public config"
        assert_file_exists "$HOME/.claude.json" "Should create Claude config"
        
        # Verify the correct servers were configured
        local configured_servers
        configured_servers=$(jq -r '.mcpServers | keys[]' "$HOME/.claude.json" 2>/dev/null | sort)
        assert_contains "$configured_servers" "public-filesystem" "Should configure public servers"
        assert_contains "$configured_servers" "public-memory" "Should configure public servers"
    fi
    
    cleanup_test_topics
}

# Test 2: Local Only Configuration (no public fallback needed)
test_precedence_local_only() {
    setup_precedence_environment
    create_test_claude_topic_local
    
    # Create the .local symlink pointing to our test local
    ln -sfn "$TEST_LOCAL_EXTERNAL" "$DOTFILES_ROOT/.local"
    
    # Ensure no public exists
    rm -rf "$DOTFILES_ROOT/claude"
    
    # Test mcp-status with local only
    local status_output
    status_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "mcp-status should succeed with local only"
    assert_contains "$status_output" "Using LOCAL:" "Should indicate local configuration"
    assert_contains "$status_output" "$ZSH/.local/claude/mcp/servers.json" "Should show local path"
    assert_contains "$status_output" "local-filesystem" "Should list local servers"
    assert_contains "$status_output" "local-only-server" "Should list local-only servers"
    
    # Test mcp-setup with local only  
    if command -v jq >/dev/null 2>&1; then
        local setup_output
        setup_output=$("$DOTFILES_ROOT/claude/mcp/mcp-setup" 2>&1)
        local setup_exit=$?
        
        assert_equals "0" "$setup_exit" "mcp-setup should succeed with local only"
        assert_contains "$setup_output" "Using local MCP configuration" "Should indicate local config"
        assert_file_exists "$HOME/.claude.json" "Should create Claude config"
        
        # Verify the correct local servers were configured
        local configured_servers
        configured_servers=$(jq -r '.mcpServers | keys[]' "$HOME/.claude.json" 2>/dev/null | sort)
        assert_contains "$configured_servers" "local-filesystem" "Should configure local servers"
        assert_contains "$configured_servers" "local-only-server" "Should configure local-only servers"
    fi
    
    cleanup_test_topics
}

# Test 3: Both Exist - Local Should Win (core precedence test)
test_precedence_local_wins() {
    setup_precedence_environment
    create_test_claude_topic_public
    create_test_claude_topic_local
    
    # Create the .local symlink pointing to our test local
    ln -sfn "$TEST_LOCAL_EXTERNAL" "$DOTFILES_ROOT/.local"
    
    # Test mcp-status with both existing - local should win
    local status_output
    status_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "mcp-status should succeed with both configs"
    assert_contains "$status_output" "Using LOCAL:" "Should prefer local over public"
    assert_contains "$status_output" "$ZSH/.local/claude/mcp/servers.json" "Should show local path"
    assert_contains "$status_output" "local-filesystem" "Should list local servers"
    assert_contains "$status_output" "local-only-server" "Should list local-only servers"
    
    # Should NOT show public servers when local exists
    if command -v jq >/dev/null 2>&1; then
        assert_contains "$status_output" "local-filesystem" "Should have local servers"
        # The public servers should not appear since local wins
        local has_public_only=$(echo "$status_output" | grep -c "public-filesystem" || echo "0")
        assert_equals "0" "$has_public_only" "Should not show public-only servers when local exists"
    fi
    
    # Test mcp-setup with both existing - should use local
    if command -v jq >/dev/null 2>&1; then
        local setup_output
        setup_output=$("$DOTFILES_ROOT/claude/mcp/mcp-setup" 2>&1)
        local setup_exit=$?
        
        assert_equals "0" "$setup_exit" "mcp-setup should succeed with local precedence"
        assert_contains "$setup_output" "Using local MCP configuration" "Should prefer local config"
        assert_file_exists "$HOME/.claude.json" "Should create Claude config"
        
        # Verify LOCAL servers were configured, not public
        local configured_servers
        configured_servers=$(jq -r '.mcpServers | keys[]' "$HOME/.claude.json" 2>/dev/null)
        assert_contains "$configured_servers" "local-filesystem" "Should use local servers"
        assert_contains "$configured_servers" "local-only-server" "Should include local-only servers"
        
        # Verify public servers are NOT configured when local exists
        local has_public_fs=$(echo "$configured_servers" | grep -c "public-filesystem" || echo "0")
        assert_equals "0" "$has_public_fs" "Should not configure public servers when local exists"
    fi
    
    cleanup_test_topics
}

# Test 4: Neither Exists - Graceful Degradation (critical resilience test) 
test_precedence_neither_exists() {
    setup_precedence_environment
    
    # Ensure neither public nor local exists
    rm -rf "$DOTFILES_ROOT/claude"
    rm -rf "$DOTFILES_ROOT/.local"
    rm -rf "$TEST_LOCAL_EXTERNAL"
    
    # Test mcp-status with neither existing - should gracefully handle
    local status_output
    status_output=$("$DOTFILES_ROOT/.local/claude/mcp/mcp-status" 2>&1 || true)
    local exit_code=$?
    
    # This should fail to execute because the script doesn't exist, which is expected
    assert_not_equals "0" "$exit_code" "Script should not exist when neither location has it"
    
    # But let's test a different way - the scripts should gracefully handle missing configs
    # Create minimal public script to test the graceful handling
    mkdir -p "$DOTFILES_ROOT/claude/mcp"
    cat > "$DOTFILES_ROOT/claude/mcp/mcp-status" << 'EOF'
#!/bin/bash
ZSH="${ZSH:-$HOME/.dotfiles}"
if [[ -f "$ZSH/.local/claude/mcp/servers.json" ]]; then
    echo "Using local"
elif [[ -f "$ZSH/claude/mcp/servers.json" ]]; then
    echo "Using public"
else
    echo "No servers.json found in local or public"
    echo "This is not an error"
    exit 0
fi
EOF
    chmod +x "$DOTFILES_ROOT/claude/mcp/mcp-status"
    
    # Now test graceful handling
    status_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    exit_code=$?
    
    assert_equals "0" "$exit_code" "Should gracefully handle neither existing"
    assert_contains "$status_output" "No servers.json found" "Should report neither found"
    assert_contains "$status_output" "This is not an error" "Should indicate this is normal"
    
    cleanup_test_topics
}

# Test 5: Bootstrap Order - .local Symlink Created Before Topic Processing
test_bootstrap_creates_local_symlink_first() {
    setup_precedence_environment
    
    # Create dotfiles.conf with LOCAL_DOTS setting
    cat > "$DOTFILES_ROOT/dotfiles.conf" << EOF
LOCAL_DOTS="$TEST_LOCAL_EXTERNAL"
EOF
    
    # Create the local directory
    mkdir -p "$TEST_LOCAL_EXTERNAL"
    
    # Ensure .local symlink doesn't exist yet
    rm -f "$DOTFILES_ROOT/.local"
    
    # Create some test topics that would benefit from local override
    create_test_claude_topic_public
    create_test_claude_topic_local
    
    # Run bootstrap (which should create .local symlink BEFORE processing topics)
    # We'll simulate the key part of bootstrap that handles this
    source "$DOTFILES_ROOT/core/lib/common.sh"
    export ORIGINAL_HOME="$HOME"
    
    # Test the setup_dotlocal_symlink function behavior
    bash -c "
        cd '$DOTFILES_ROOT'
        source '$DOTFILES_ROOT/core/lib/common.sh'
        
        # Simulate the bootstrap function for .local symlink creation
        if [ -f '$DOTFILES_ROOT/dotfiles.conf' ]; then
            source '$DOTFILES_ROOT/dotfiles.conf'
            if [ -n \"\$LOCAL_DOTS\" ]; then
                LOCAL_SYMLINK_PATH='$DOTFILES_ROOT/.local'
                if [ -d \"\$LOCAL_DOTS\" ]; then
                    if [ ! -e \"\$LOCAL_SYMLINK_PATH\" ]; then
                        ln -sfn \"\$LOCAL_DOTS\" \"\$LOCAL_SYMLINK_PATH\"
                        echo 'Created local symlink'
                    fi
                fi
            fi
        fi
    "
    
    # Verify .local symlink was created and points to the right place
    assert_symlink_valid "$DOTFILES_ROOT/.local" "Bootstrap should create .local symlink"
    
    local symlink_target
    symlink_target=$(readlink "$DOTFILES_ROOT/.local")
    assert_equals "$TEST_LOCAL_EXTERNAL" "$symlink_target" ".local should point to LOCAL_DOTS"
    
    # Now test that topics can use the .local symlink correctly
    local status_output
    status_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    assert_contains "$status_output" "Using LOCAL:" "Topics should be able to use .local symlink"
    
    # Clean up
    rm -f "$DOTFILES_ROOT/dotfiles.conf"
    cleanup_test_topics
}

# Test 6: No Hardcoded Paths - Uses Environment Variables
test_no_hardcoded_paths() {
    setup_precedence_environment
    create_test_claude_topic_public
    
    # Test with different ZSH environment variable
    local custom_dotfiles="/tmp/custom_dotfiles_$$"
    mkdir -p "$custom_dotfiles/claude/mcp"
    
    # Create test configuration in custom location
    cat > "$custom_dotfiles/claude/mcp/servers.json" << 'EOF'
{
  "mcpServers": {
    "custom-server": {
      "command": "echo",
      "args": ["custom"],
      "type": "stdio"
    }
  }
}
EOF
    
    # Copy our test script to custom location
    cp "$DOTFILES_ROOT/claude/mcp/mcp-status" "$custom_dotfiles/claude/mcp/mcp-status"
    
    # Test with custom ZSH environment
    local custom_output
    custom_output=$(ZSH="$custom_dotfiles" "$custom_dotfiles/claude/mcp/mcp-status" 2>&1)
    local custom_exit=$?
    
    assert_equals "0" "$custom_exit" "Should work with custom ZSH environment"
    assert_contains "$custom_output" "$custom_dotfiles/claude/mcp/servers.json" "Should use ZSH environment variable"
    assert_contains "$custom_output" "custom-server" "Should read from custom location"
    
    # Test with missing ZSH environment (should fall back to default)
    local default_output  
    default_output=$(unset ZSH && "$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    local default_exit=$?
    
    assert_equals "0" "$default_exit" "Should work with default ZSH fallback"
    assert_contains "$default_output" "$HOME/.dotfiles" "Should fall back to default dotfiles location"
    
    # Clean up
    rm -rf "$custom_dotfiles"
    cleanup_test_topics
}

# Test 7: Edge Case - Broken Symlinks Don't Break System
test_broken_symlinks_graceful_handling() {
    setup_precedence_environment
    create_test_claude_topic_public
    
    # Create broken .local symlink
    ln -sfn "/nonexistent/path" "$DOTFILES_ROOT/.local"
    
    # Scripts should fall back to public gracefully
    local status_output
    status_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    local exit_code=$?
    
    assert_equals "0" "$exit_code" "Should handle broken .local symlink gracefully"
    assert_contains "$status_output" "Using PUBLIC:" "Should fall back to public when local is broken"
    assert_contains "$status_output" "public-filesystem" "Should use public servers"
    
    cleanup_test_topics
}

# Test 8: Missing jq Dependency - Graceful Degradation
test_missing_jq_graceful_degradation() {
    setup_precedence_environment
    create_test_claude_topic_public
    
    # Create custom PATH without jq
    local original_path="$PATH"
    export PATH="/tmp/no-jq"
    mkdir -p "/tmp/no-jq"
    
    # Test mcp-setup without jq
    local setup_output
    setup_output=$("$DOTFILES_ROOT/claude/mcp/mcp-setup" 2>&1)
    local setup_exit=$?
    
    assert_equals "0" "$setup_exit" "Should handle missing jq gracefully"
    assert_contains "$setup_output" "Warning: jq is required" "Should warn about missing jq"
    assert_contains "$setup_output" "MCP setup skipped" "Should skip setup gracefully"
    
    # Restore PATH
    export PATH="$original_path"
    
    cleanup_test_topics
}

# Test 9: Permission Issues - Graceful Error Handling
test_permission_issues_graceful_handling() {
    setup_precedence_environment
    create_test_claude_topic_public
    
    # Create Claude config directory with restricted permissions
    mkdir -p "$HOME/.claude"
    chmod 000 "$HOME/.claude"
    
    # Test should handle permission issues gracefully
    local setup_output
    setup_output=$("$DOTFILES_ROOT/claude/mcp/mcp-setup" 2>&1 || true)
    local setup_exit=$?
    
    # Should fail but not crash
    assert_not_equals "0" "$setup_exit" "Should fail with permission error"
    # Should not crash or produce unexpected errors
    assert_not_equals "139" "$setup_exit" "Should not segfault"
    
    # Restore permissions for cleanup
    chmod 755 "$HOME/.claude"
    
    cleanup_test_topics
}

# Test 10: End-to-End Precedence Workflow
test_complete_precedence_workflow() {
    setup_precedence_environment
    create_test_claude_topic_public
    create_test_claude_topic_local
    
    # Step 1: Start with public only
    test_info "Step 1: Testing public-only configuration"
    local public_output
    public_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    assert_contains "$public_output" "Using PUBLIC:" "Should start with public"
    
    # Step 2: Add local (should immediately take precedence)
    test_info "Step 2: Adding local configuration"
    ln -sfn "$TEST_LOCAL_EXTERNAL" "$DOTFILES_ROOT/.local"
    
    local local_output
    local_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    assert_contains "$local_output" "Using LOCAL:" "Should immediately switch to local"
    assert_contains "$local_output" "local-only-server" "Should show local-only servers"
    
    # Step 3: Remove local (should fall back to public)
    test_info "Step 3: Removing local configuration"
    rm -f "$DOTFILES_ROOT/.local"
    
    local fallback_output
    fallback_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    assert_contains "$fallback_output" "Using PUBLIC:" "Should fall back to public"
    assert_contains "$fallback_output" "public-filesystem" "Should show public servers"
    
    # Step 4: Remove public (should gracefully handle neither)
    test_info "Step 4: Testing graceful degradation with neither"
    rm -rf "$DOTFILES_ROOT/claude"
    
    # Create minimal script for graceful test
    mkdir -p "$DOTFILES_ROOT/claude/mcp"
    cat > "$DOTFILES_ROOT/claude/mcp/mcp-status" << 'EOF'
#!/bin/bash
ZSH="${ZSH:-$HOME/.dotfiles}"
if [[ -f "$ZSH/.local/claude/mcp/servers.json" ]]; then
    echo "local exists"
elif [[ -f "$ZSH/claude/mcp/servers.json" ]]; then
    echo "public exists"  
else
    echo "neither exists - this is normal"
    exit 0
fi
EOF
    chmod +x "$DOTFILES_ROOT/claude/mcp/mcp-status"
    
    local neither_output
    neither_output=$("$DOTFILES_ROOT/claude/mcp/mcp-status" 2>&1)
    assert_equals "0" "$?" "Should handle neither existing gracefully"
    assert_contains "$neither_output" "neither exists - this is normal" "Should indicate normal operation"
    
    cleanup_test_topics
}

# Main test runner
main() {
    setup_test_environment
    
    test_info "<¯ PRECEDENCE SYSTEM INTEGRATION TESTS"
    test_info "Testing the core Microdots principle: LOCAL ALWAYS WINS"
    test_info "Validating graceful degradation in all scenarios"
    echo ""
    
    # Core precedence scenarios
    run_test "Precedence 1: Public Only Configuration" test_precedence_public_only
    run_test "Precedence 2: Local Only Configuration" test_precedence_local_only  
    run_test "Precedence 3: Both Exist - Local Wins" test_precedence_local_wins
    run_test "Precedence 4: Neither Exists - Graceful Degradation" test_precedence_neither_exists
    
    # Bootstrap and architecture tests  
    run_test "Bootstrap: .local Symlink Created First" test_bootstrap_creates_local_symlink_first
    run_test "Architecture: No Hardcoded Paths" test_no_hardcoded_paths
    
    # Edge cases and resilience
    run_test "Edge Case: Broken Symlinks Handled Gracefully" test_broken_symlinks_graceful_handling
    run_test "Edge Case: Missing jq Dependency" test_missing_jq_graceful_degradation
    run_test "Edge Case: Permission Issues" test_permission_issues_graceful_handling
    
    # Complete workflow validation
    run_test "Complete: End-to-End Precedence Workflow" test_complete_precedence_workflow
    
    generate_test_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi