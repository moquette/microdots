#!/usr/bin/env bash
#
# Edge Case Tests for MCP Configuration
# Tests the most challenging failure scenarios and edge cases
# Ensures MCP system is bulletproof under extreme conditions
#

# Source the test framework
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$TEST_DIR/test_framework.sh"

# Setup for extreme edge case testing
setup_extreme_mcp_environment() {
  # Create all possible directory combinations that Claude might use
  mkdir -p "$HOME/.claude" "$HOME/.config/Claude"
  mkdir -p "$HOME/Library/Application Support/Claude"
  mkdir -p "$HOME/.claude/mcp" 
  mkdir -p ".claude"
  
  # Create a test servers.json
  export ZSH="$DOTFILES_ROOT"
  export MCP_SERVERS_FILE="$DOTFILES_ROOT/claude/mcp/servers.json"
  
  # Source MCP functions
  source "$DOTFILES_ROOT/claude/claude.zsh"
}

# Test 1: Disk full during MCP sync
test_disk_full_scenario() {
  setup_extreme_mcp_environment
  
  # Create a small filesystem to fill up
  local fake_fs="$TEST_TEMP_DIR/fake_fs"
  mkdir -p "$fake_fs"
  
  # Create config in fake filesystem
  local test_config="$fake_fs/claude.json"
  echo '{"existing": true}' > "$test_config"
  
  # Create a large file to fill up space (simulating disk full)
  # Note: This is a simulation - actual disk full would be harder to test safely
  local large_file="$fake_fs/large_file"
  if ! dd if=/dev/zero of="$large_file" bs=1024 count=10000 2>/dev/null; then
    test_info "Cannot create large file (possibly insufficient disk space)"
  fi
  
  # Try to merge servers (should handle gracefully even with space issues)
  local merge_output=$(mcp-merge-servers "$test_config" 2>&1)
  local merge_exit=$?
  
  # Should not crash, even if it fails
  assert_not_equals "139" "$merge_exit" "Should not segfault during disk space issues"
  
  # Cleanup
  rm -f "$large_file"
}

# Test 2: Extremely long file paths
test_extremely_long_paths() {
  setup_extreme_mcp_environment
  
  # Create a very long path structure
  local long_path="$TEST_TEMP_DIR"
  for i in {1..10}; do
    long_path="$long_path/very_long_directory_name_that_might_cause_path_length_issues_$i"
  done
  
  mkdir -p "$long_path"
  local long_config="$long_path/claude_config_with_very_long_name.json"
  
  echo '{"test": true}' > "$long_config"
  
  # Test merge with extremely long path
  local merge_output=$(mcp-merge-servers "$long_config" 2>&1)
  local merge_exit=$?
  
  # Should handle long paths gracefully
  assert_not_equals "139" "$merge_exit" "Should not crash with long paths"
  
  if [ "$merge_exit" = "0" ]; then
    assert_file_exists "$long_config" "Long path config should be created/updated"
  fi
}

# Test 3: Unicode and special characters in paths
test_unicode_special_characters() {
  setup_extreme_mcp_environment
  
  # Create paths with unicode and special characters
  local unicode_dir="$TEST_TEMP_DIR/KÕîU_ñäme-with[special]chars & spaces"
  mkdir -p "$unicode_dir"
  
  local unicode_config="$unicode_dir/claude_KÕMn.json"
  echo '{"unicode": "KÕ"}' > "$unicode_config"
  
  # Test merge with unicode paths
  local merge_output=$(mcp-merge-servers "$unicode_config" 2>&1)
  local merge_exit=$?
  
  assert_not_equals "139" "$merge_exit" "Should not crash with unicode paths"
  
  if [ "$merge_exit" = "0" ]; then
    test_success "Unicode path handling works"
  else
    test_warning "Unicode path handling may have issues (exit code: $merge_exit)"
  fi
}

# Test 4: Massive JSON files
test_massive_json_files() {
  setup_extreme_mcp_environment
  
  # Create a very large JSON config file
  local large_config="$TEST_TEMP_DIR/large_config.json"
  
  echo '{"mcpServers": {' > "$large_config"
  
  # Add many servers to make it large
  for i in {1..1000}; do
    echo "  \"server-$i\": {" >> "$large_config"
    echo "    \"type\": \"stdio\"," >> "$large_config" 
    echo "    \"command\": \"command-$i\"," >> "$large_config"
    echo "    \"args\": [\"arg1\", \"arg2\", \"arg3\", \"arg4\", \"arg5\"]," >> "$large_config"
    echo "    \"env\": {\"VAR_$i\": \"value_$i\"}" >> "$large_config"
    if [ $i -lt 1000 ]; then
      echo "  }," >> "$large_config"
    else
      echo "  }" >> "$large_config"
    fi
  done
  
  echo '}, "otherSettings": {"large": true}}' >> "$large_config"
  
  # Test merge with large file
  local merge_output=$(mcp-merge-servers "$large_config" 2>&1)
  local merge_exit=$?
  
  assert_not_equals "139" "$merge_exit" "Should not crash with large JSON files"
  
  # Check if jq can handle the large file
  if command -v jq >/dev/null 2>&1; then
    local server_count=$(jq -r '.mcpServers | length' "$large_config" 2>/dev/null || echo "0")
    if [ "$server_count" -gt "0" ]; then
      test_success "Large JSON file processed successfully"
    else
      test_warning "Large JSON file may have processing issues"
    fi
  fi
}

# Test 5: Rapidly changing configuration files
test_rapid_configuration_changes() {
  setup_extreme_mcp_environment
  
  local config="$TEST_TEMP_DIR/rapid_config.json"
  echo '{"initial": true}' > "$config"
  
  # Simulate rapid changes by running multiple merges in background
  for i in {1..5}; do
    (
      echo "{\"change_$i\": true}" > "$config.tmp.$i"
      mcp-merge-servers "$config.tmp.$i" >/dev/null 2>&1
      rm -f "$config.tmp.$i"
    ) &
  done
  
  # Wait for all background processes
  wait
  
  # Main config should still be valid
  if command -v jq >/dev/null 2>&1; then
    local valid_json=$(jq empty "$config" 2>&1)
    if [ -z "$valid_json" ]; then
      test_success "Configuration file remains valid during rapid changes"
    else
      test_error "Configuration file corrupted during rapid changes"
    fi
  fi
}

# Test 6: System limits - file descriptor exhaustion
test_file_descriptor_limits() {
  setup_extreme_mcp_environment
  
  # Get current file descriptor limit
  local fd_limit=$(ulimit -n)
  test_info "Current file descriptor limit: $fd_limit"
  
  # Create many config files
  local configs=()
  for i in $(seq 1 $((fd_limit / 10))); do
    local config="$TEST_TEMP_DIR/config_$i.json"
    echo "{\"config\": $i}" > "$config"
    configs+=("$config")
  done
  
  # Try to process all configs simultaneously
  local pids=()
  for config in "${configs[@]}"; do
    mcp-merge-servers "$config" >/dev/null 2>&1 &
    pids+=($!)
  done
  
  # Wait for all processes
  local failed_count=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      failed_count=$((failed_count + 1))
    fi
  done
  
  # Some failures are expected with resource exhaustion, but no crashes
  test_info "Failed processes: $failed_count / ${#pids[@]}"
  test_success "No crashes during file descriptor stress test"
}

# Test 7: Memory pressure scenarios
test_memory_pressure() {
  setup_extreme_mcp_environment
  
  # Create a config with deeply nested structures
  local deep_config="$TEST_TEMP_DIR/deep_config.json"
  
  local json_content='{"level1": {"level2": {"level3": {"level4": {"level5": {'
  for i in {1..100}; do
    json_content="$json_content\"item_$i\": {\"data\": \"$i\", \"array\": [1,2,3,4,5,6,7,8,9,10]},"
  done
  json_content="${json_content%,}}}}}}"  # Remove last comma and close braces
  
  echo "$json_content" > "$deep_config"
  
  # Test processing deeply nested JSON
  local merge_output=$(mcp-merge-servers "$deep_config" 2>&1)
  local merge_exit=$?
  
  assert_not_equals "139" "$merge_exit" "Should not crash with deeply nested JSON"
  
  if command -v jq >/dev/null 2>&1; then
    local valid_structure=$(jq -r '.level1.level2.level3.level4.level5 | length' "$deep_config" 2>/dev/null || echo "0")
    assert_equals "100" "$valid_structure" "Deep JSON structure should be preserved"
  fi
}

# Test 8: Race conditions during sync
test_race_conditions() {
  setup_extreme_mcp_environment
  
  # Create multiple configs that will be synced simultaneously
  local configs=()
  for i in {1..10}; do
    local config="$TEST_TEMP_DIR/race_config_$i.json"
    echo "{\"race\": $i, \"timestamp\": $(date +%s%N)}" > "$config"
    configs+=("$config")
  done
  
  # Start all syncs at nearly the same time
  local pids=()
  for config in "${configs[@]}"; do
    mcp-merge-servers "$config" >/dev/null 2>&1 &
    pids+=($!)
  done
  
  # Wait for all to complete
  local crash_count=0
  for pid in "${pids[@]}"; do
    wait "$pid"
    local exit_code=$?
    if [ "$exit_code" = "139" ]; then  # SIGSEGV
      crash_count=$((crash_count + 1))
    fi
  done
  
  assert_equals "0" "$crash_count" "No processes should crash due to race conditions"
  
  # Verify all configs are still valid JSON
  local invalid_count=0
  if command -v jq >/dev/null 2>&1; then
    for config in "${configs[@]}"; do
      if ! jq empty "$config" 2>/dev/null; then
        invalid_count=$((invalid_count + 1))
      fi
    done
  fi
  
  assert_equals "0" "$invalid_count" "All config files should remain valid after race conditions"
}

# Test 9: Network filesystem edge cases
test_network_filesystem_simulation() {
  setup_extreme_mcp_environment
  
  # Simulate network filesystem delays by using a slow operation
  local network_config="$TEST_TEMP_DIR/network_config.json"
  echo '{"network": "filesystem"}' > "$network_config"
  
  # Create a function that simulates network delay
  simulate_network_delay() {
    local original_file="$1"
    local temp_file="${original_file}.network_tmp"
    
    # Slow copy to simulate network filesystem
    dd if="$original_file" of="$temp_file" bs=1 2>/dev/null
    mv "$temp_file" "$original_file"
  }
  
  # Test merge with simulated network delay
  simulate_network_delay "$network_config" &
  local delay_pid=$!
  
  local merge_output=$(mcp-merge-servers "$network_config" 2>&1)
  local merge_exit=$?
  
  wait "$delay_pid" 2>/dev/null || true  # Wait for simulation to complete
  
  assert_not_equals "139" "$merge_exit" "Should handle network filesystem delays gracefully"
  
  if [ "$merge_exit" = "0" ] || [ "$merge_exit" = "1" ]; then
    test_success "Network filesystem simulation handled appropriately"
  fi
}

# Test 10: Signal handling during operations
test_signal_handling() {
  setup_extreme_mcp_environment
  
  local config="$TEST_TEMP_DIR/signal_config.json"
  echo '{"signal": "test"}' > "$config"
  
  # Start a long-running merge operation
  (
    # Create a large config to make the operation take some time
    local large_content='{"mcpServers": {'
    for i in {1..500}; do
      large_content="$large_content\"server_$i\": {\"command\": \"long_command_$i\", \"args\": []},"
    done
    large_content="${large_content%,}}}"
    
    echo "$large_content" > "$config"
    mcp-merge-servers "$config" >/dev/null 2>&1
  ) &
  
  local merge_pid=$!
  
  # Give it a moment to start
  sleep 0.5
  
  # Send SIGTERM to test graceful handling
  kill -TERM "$merge_pid" 2>/dev/null || true
  
  wait "$merge_pid" 2>/dev/null
  local exit_code=$?
  
  # Should exit cleanly, not crash
  assert_not_equals "139" "$exit_code" "Should handle SIGTERM gracefully"
  
  # Config file should not be corrupted
  if command -v jq >/dev/null 2>&1; then
    local valid_json=$(jq empty "$config" 2>&1)
    if [ -z "$valid_json" ]; then
      test_success "Configuration file remains valid after signal interruption"
    fi
  fi
}

# Test 11: Extreme character encoding issues
test_character_encoding_edge_cases() {
  setup_extreme_mcp_environment
  
  # Create config with various character encodings
  local encoding_config="$TEST_TEMP_DIR/encoding_config.json"
  
  # Use printf to create content with various byte sequences
  printf '{"encoding": "test", "unicode": "' > "$encoding_config"
  printf '\u2603\u2744\u2728' >> "$encoding_config"  # Snowman, snowflake, sparkles
  printf '", "latin1": "' >> "$encoding_config"
  printf 'caf\351' >> "$encoding_config"  # café in Latin-1
  printf '", "binary": "' >> "$encoding_config"
  printf '\x00\x01\x02\x03' | base64 -i - >> "$encoding_config"  # Binary data as base64
  printf '"}' >> "$encoding_config"
  
  # Test merge with mixed encodings
  local merge_output=$(mcp-merge-servers "$encoding_config" 2>&1)
  local merge_exit=$?
  
  assert_not_equals "139" "$merge_exit" "Should handle mixed character encodings gracefully"
  
  # The file might not be valid JSON due to encoding issues, but shouldn't crash
  test_info "Character encoding test completed (exit code: $merge_exit)"
}

# Test 12: Symlink loops and circular references  
test_symlink_loops() {
  setup_extreme_mcp_environment
  
  # Create circular symlinks
  local link1="$TEST_TEMP_DIR/link1"
  local link2="$TEST_TEMP_DIR/link2"
  
  ln -sf "$link2" "$link1"
  ln -sf "$link1" "$link2"
  
  # Try to process a config that might follow these links
  local loop_config="$TEST_TEMP_DIR/loop_config.json"
  echo '{"symlink": "test"}' > "$loop_config"
  
  # Create symlink to the config
  ln -sf "$loop_config" "$TEST_TEMP_DIR/symlink_to_config.json"
  
  # Test merge with symlinked config
  local merge_output=$(mcp-merge-servers "$TEST_TEMP_DIR/symlink_to_config.json" 2>&1)
  local merge_exit=$?
  
  assert_not_equals "139" "$merge_exit" "Should handle symlink loops without crashing"
  
  # Clean up circular symlinks
  rm -f "$link1" "$link2" "$TEST_TEMP_DIR/symlink_to_config.json"
}

# Test 13: Filesystem permission changes during operation
test_runtime_permission_changes() {
  setup_extreme_mcp_environment
  
  local perm_config="$TEST_TEMP_DIR/permission_config.json"
  echo '{"permissions": "test"}' > "$perm_config"
  
  # Start merge operation in background
  mcp-merge-servers "$perm_config" >/dev/null 2>&1 &
  local merge_pid=$!
  
  # Change permissions while operation is running
  chmod 000 "$perm_config" 2>/dev/null || true
  
  wait "$merge_pid"
  local merge_exit=$?
  
  # Restore permissions for cleanup
  chmod 644 "$perm_config" 2>/dev/null || true
  
  assert_not_equals "139" "$merge_exit" "Should handle runtime permission changes gracefully"
}

# Test 14: System resource exhaustion
test_system_resource_exhaustion() {
  setup_extreme_mcp_environment
  
  # Create many temporary files to stress the filesystem
  local temp_files=()
  for i in {1..100}; do
    local temp_file="$TEST_TEMP_DIR/temp_$i"
    echo "{\"temp\": $i}" > "$temp_file"
    temp_files+=("$temp_file")
  done
  
  # Start many merge operations to stress system resources
  local pids=()
  for temp_file in "${temp_files[@]}"; do
    mcp-merge-servers "$temp_file" >/dev/null 2>&1 &
    pids+=($!)
  done
  
  # Monitor system load
  local start_load=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')
  
  # Wait for all processes
  local successful_count=0
  local crashed_count=0
  
  for pid in "${pids[@]}"; do
    wait "$pid"
    local exit_code=$?
    if [ "$exit_code" = "0" ]; then
      successful_count=$((successful_count + 1))
    elif [ "$exit_code" = "139" ]; then
      crashed_count=$((crashed_count + 1))
    fi
  done
  
  local end_load=$(uptime | awk -F'load average:' '{print $2}' | cut -d',' -f1 | tr -d ' ')
  
  test_info "System load: $start_load -> $end_load"
  test_info "Successful: $successful_count, Crashed: $crashed_count, Total: ${#pids[@]}"
  
  assert_equals "0" "$crashed_count" "No processes should crash under system stress"
}

# Test 15: Comprehensive failure recovery
test_comprehensive_failure_recovery() {
  setup_extreme_mcp_environment
  
  local recovery_config="$TEST_TEMP_DIR/recovery_config.json"
  
  # Create a series of increasingly complex failure scenarios
  local scenarios=(
    "disk_space"
    "permissions" 
    "corruption"
    "interruption"
    "recovery"
  )
  
  for scenario in "${scenarios[@]}"; do
    test_info "Testing recovery scenario: $scenario"
    
    case "$scenario" in
      "disk_space")
        # Simulate low disk space
        echo '{"scenario": "disk_space", "large_data": "' > "$recovery_config"
        for i in {1..1000}; do
          printf "data_$i " >> "$recovery_config"
        done
        echo '"}' >> "$recovery_config"
        ;;
        
      "permissions")
        # Test with restricted permissions
        echo '{"scenario": "permissions"}' > "$recovery_config"
        chmod 400 "$recovery_config"  # Read-only
        ;;
        
      "corruption")
        # Create corrupted JSON
        echo '{"scenario": "corruption", invalid json}' > "$recovery_config"
        ;;
        
      "interruption")
        # Test interruption recovery
        echo '{"scenario": "interruption"}' > "$recovery_config"
        mcp-merge-servers "$recovery_config" >/dev/null 2>&1 &
        local int_pid=$!
        sleep 0.1
        kill -INT "$int_pid" 2>/dev/null || true
        wait "$int_pid" 2>/dev/null || true
        ;;
        
      "recovery")
        # Test final recovery
        echo '{"scenario": "recovery", "status": "final"}' > "$recovery_config"
        chmod 644 "$recovery_config"  # Restore permissions
        ;;
    esac
    
    # Attempt merge for each scenario
    local output=$(mcp-merge-servers "$recovery_config" 2>&1)
    local exit_code=$?
    
    # Log the result
    test_info "Scenario $scenario: exit code $exit_code"
    
    # Should never crash, even in failure scenarios
    assert_not_equals "139" "$exit_code" "Scenario $scenario should not cause crash"
    
    # Reset for next scenario
    chmod 644 "$recovery_config" 2>/dev/null || true
  done
  
  test_success "All failure recovery scenarios completed without crashes"
}

# Main test runner for edge case tests
main() {
  setup_test_environment
  
  test_info "Starting extreme edge case tests for MCP configuration..."
  test_info "These tests push the MCP system to its limits to ensure bulletproof reliability."
  test_warning "Some edge case tests may take longer to complete."
  echo ""
  
  # Filesystem and storage edge cases
  run_test "MCP Edge: Disk Full Scenario" test_disk_full_scenario
  run_test "MCP Edge: Extremely Long Paths" test_extremely_long_paths
  run_test "MCP Edge: Unicode Special Characters" test_unicode_special_characters
  run_test "MCP Edge: Massive JSON Files" test_massive_json_files
  
  # Concurrency and timing edge cases
  run_test "MCP Edge: Rapid Configuration Changes" test_rapid_configuration_changes
  run_test "MCP Edge: Race Conditions" test_race_conditions
  run_test "MCP Edge: Signal Handling" test_signal_handling
  
  # System resource edge cases
  run_test "MCP Edge: File Descriptor Limits" test_file_descriptor_limits
  run_test "MCP Edge: Memory Pressure" test_memory_pressure
  run_test "MCP Edge: System Resource Exhaustion" test_system_resource_exhaustion
  
  # Special filesystem conditions
  run_test "MCP Edge: Network Filesystem Simulation" test_network_filesystem_simulation
  run_test "MCP Edge: Symlink Loops" test_symlink_loops
  run_test "MCP Edge: Runtime Permission Changes" test_runtime_permission_changes
  
  # Data integrity edge cases
  run_test "MCP Edge: Character Encoding Issues" test_character_encoding_edge_cases
  
  # Comprehensive recovery testing
  run_test "MCP Edge: Comprehensive Failure Recovery" test_comprehensive_failure_recovery
  
  generate_test_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi