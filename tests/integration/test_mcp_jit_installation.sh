#!/usr/bin/env bash

# Test: MCP Just-In-Time Installation Configuration
# Purpose: Validate that MCP servers are properly configured for on-demand installation
# Note: MCP servers use 'npx -y' for just-in-time installation, not pre-installation

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source test framework
source "$SCRIPT_DIR/../test_framework.sh"

# Test MCP servers are configured for JIT installation
test_mcp_jit_configuration() {
  local servers_json="$HOME/.dotlocal/claude/mcp/servers.json"
  
  if [[ ! -f "$servers_json" ]]; then
    skip_test "MCP servers.json not found (expected in dotlocal)"
    return
  fi
  
  # Check that servers use npx -y for just-in-time installation
  local npx_count=$(grep -c '"npx"' "$servers_json" 2>/dev/null || echo "0")
  local dash_y_count=$(grep -c '"-y"' "$servers_json" 2>/dev/null || echo "0")
  
  assert_greater_than "$npx_count" "0" "MCP servers should use npx command"
  assert_equals "$npx_count" "$dash_y_count" "All npx commands should use -y flag for JIT installation"
  
  # Verify specific servers are configured (not installed, just configured)
  if command -v jq >/dev/null 2>&1; then
    local filesystem=$(jq -r '.mcpServers.filesystem.command' "$servers_json" 2>/dev/null)
    local memory=$(jq -r '.mcpServers.memory.command' "$servers_json" 2>/dev/null)
    local context7=$(jq -r '.mcpServers.context7.command' "$servers_json" 2>/dev/null)
    
    assert_equals "npx" "$filesystem" "Filesystem server should use npx"
    assert_equals "npx" "$memory" "Memory server should use npx"
    assert_equals "npx" "$context7" "Context7 server should use npx"
    
    # Check that -y flag is in args
    local filesystem_y=$(jq -r '.mcpServers.filesystem.args[0]' "$servers_json" 2>/dev/null)
    assert_equals "-y" "$filesystem_y" "Filesystem server should have -y as first arg"
  else
    # Fallback without jq
    assert_contains "$(cat "$servers_json")" '"command": "npx"' "Servers should use npx command"
    assert_contains "$(cat "$servers_json")" '"-y"' "Servers should use -y flag"
  fi
}

# Test that MCP servers are NOT pre-installed (intended behavior)
test_mcp_not_preinstalled() {
  # Check that MCP packages are NOT installed globally
  # This is the EXPECTED behavior - they install on first use
  
  local mcp_packages=(
    "@modelcontextprotocol/server-filesystem"
    "@modelcontextprotocol/server-memory"
    "@modelcontextprotocol/server-sequential-thinking"
    "@upstash/context7-mcp"
    "@modelcontextprotocol/server-puppeteer"
    "openmemory"
  )
  
  local preinstalled_count=0
  for package in "${mcp_packages[@]}"; do
    # Check if package is globally installed
    if npm list -g "$package" >/dev/null 2>&1; then
      ((preinstalled_count++))
    fi
  done
  
  # We expect 0 pre-installed packages (they install on demand)
  assert_equals "0" "$preinstalled_count" "MCP packages should NOT be pre-installed (JIT is intended)"
}

# Test that servers.json is properly linked
test_mcp_servers_symlink() {
  local expected_link="$HOME/.claude/mcp/servers.json"
  local expected_target="$HOME/.dotlocal/claude/mcp/servers.json"
  
  if [[ -L "$expected_link" ]]; then
    local actual_target=$(readlink "$expected_link")
    assert_equals "$expected_target" "$actual_target" "MCP servers.json should link to dotlocal"
  else
    # It's OK if the symlink doesn't exist yet (created on demand)
    echo "ℹ️  MCP servers.json symlink not created yet (will be created by install script)"
  fi
}

# Test Claude configuration has MCP servers
test_claude_config_has_mcp() {
  local claude_config="$HOME/.claude/.claude.json"
  
  if [[ ! -f "$claude_config" ]]; then
    skip_test "Claude config not found (will be created on first MCP setup)"
    return
  fi
  
  if command -v jq >/dev/null 2>&1; then
    local server_count=$(jq -r '.mcpServers | length' "$claude_config" 2>/dev/null || echo "0")
    assert_not_equals "0" "$server_count" "Claude config should have MCP servers configured"
  else
    assert_contains "$(cat "$claude_config")" '"mcpServers"' "Claude config should have MCP servers section"
  fi
}

# Test that the MCP documentation explains JIT installation
test_mcp_documentation() {
  local mcp_readme="$DOTFILES_ROOT/claude/mcp/README.md"
  
  if [[ -f "$mcp_readme" ]]; then
    assert_contains "$(cat "$mcp_readme")" "npx" "Documentation should mention npx usage"
    # Documentation should explain on-demand installation
    if grep -q "just-in-time\|on-demand\|JIT\|automatically installed" "$mcp_readme" 2>/dev/null; then
      echo "✅ Documentation explains on-demand installation"
    else
      echo "ℹ️  Documentation could better explain JIT installation behavior"
    fi
  else
    echo "ℹ️  MCP README not found - consider documenting JIT installation"
  fi
}

# Run tests
echo "Running MCP Just-In-Time Installation Tests..."
echo "=============================================="
run_test "MCP JIT configuration" test_mcp_jit_configuration
run_test "MCP not preinstalled (expected)" test_mcp_not_preinstalled
run_test "MCP servers symlink" test_mcp_servers_symlink
run_test "Claude config has MCP" test_claude_config_has_mcp
run_test "MCP documentation" test_mcp_documentation

echo ""
echo "📝 Note: MCP servers use 'npx -y' for just-in-time installation."
echo "   This means packages are installed automatically on first use,"
echo "   not during dotfiles setup. This is the intended behavior!"
echo "   Missing packages are EXPECTED - they install when needed."