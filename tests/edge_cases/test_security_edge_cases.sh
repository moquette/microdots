#!/usr/bin/env bash
#
# Security and Edge Case Tests
# Tests security vulnerabilities, edge cases, and failure scenarios
#

# Source the test framework
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$TEST_DIR/test_framework.sh"

# Test path traversal protection
test_path_traversal_protection() {
  # Create malicious symlink files that try to escape the dotfiles directory
  create_test_topic "malicious_topic" false false false
  
  # Try to create symlink files with path traversal
  echo "malicious content" > "$DOTFILES_ROOT/malicious_topic/../../etc/passwd.symlink" 2>/dev/null || true
  echo "malicious content" > "$DOTFILES_ROOT/malicious_topic/../../../root/.ssh/id_rsa.symlink" 2>/dev/null || true
  
  # Run bootstrap - should not create dangerous symlinks
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  
  # Verify no malicious symlinks were created
  assert_file_not_exists "$HOME/../etc/passwd" "Should not create passwd symlink through traversal"
  assert_file_not_exists "$HOME/../../root/.ssh/id_rsa" "Should not create ssh key symlink"
  
  remove_test_topic "malicious_topic"
}

# Test broken symlinks recovery
test_broken_symlinks_recovery() {
  # Create a topic with valid symlinks
  create_test_topic "symlink_recovery_test" false true false
  
  # Run bootstrap to create symlinks
  "$DOTFILES_ROOT/core/commands/bootstrap" >/dev/null 2>&1
  
  # Verify symlink exists and is valid
  assert_symlink_valid "$HOME/.testrc" "Initial symlink should be valid"
  
  # Break the symlink by removing the source
  rm -f "$DOTFILES_ROOT/symlink_recovery_test/testrc.symlink"
  
  # Verify symlink is now broken
  if [ -L "$HOME/.testrc" ] && [ ! -e "$HOME/.testrc" ]; then
    test_success "Symlink correctly detected as broken"
  else
    test_error "Symlink should be broken but wasn't detected as such"
  fi
  
  # Run bootstrap again - should clean broken symlinks and recreate if source exists
  echo "recovered content" > "$DOTFILES_ROOT/symlink_recovery_test/testrc.symlink"
  
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  
  # Should have valid symlink again
  assert_symlink_valid "$HOME/.testrc" "Symlink should be recovered"
  
  # Verify content is correct
  local content=$(cat "$HOME/.testrc")
  assert_contains "$content" "recovered content" "Symlink should point to recovered file"
  
  remove_test_topic "symlink_recovery_test"
}

# Test permission failures
test_permission_failures() {
  # Create a directory we can't write to
  local readonly_dir="$TEST_TEMP_DIR/readonly_test"
  mkdir -p "$readonly_dir"
  chmod 444 "$readonly_dir"  # Read-only
  
  # Override HOME to point to readonly directory
  local original_home="$HOME"
  export HOME="$readonly_dir"
  
  # Create test topic
  create_test_topic "permission_test" false true false
  
  # Run bootstrap - should handle permission failure gracefully
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  local exit_code=$?
  
  # Should continue despite permission failures
  assert_not_equals "0" "$exit_code" "Bootstrap should fail with permission errors"
  
  # Restore permissions and HOME
  chmod 755 "$readonly_dir"
  export HOME="$original_home"
  
  remove_test_topic "permission_test"
}

# Test extremely long file names
test_long_filenames() {
  # Create topic with very long filename
  local long_name="a"
  for i in {1..100}; do
    long_name="${long_name}verylongname"
  done
  
  create_test_topic "long_filename_test" false false false
  
  # Try to create a symlink file with extremely long name (should be handled gracefully)
  echo "content" > "$DOTFILES_ROOT/long_filename_test/${long_name:0:200}.symlink" 2>/dev/null || true
  
  # Run bootstrap
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  
  # Should complete without crashing
  assert_contains "$output" "Bootstrap complete" "Should complete despite long filename"
  
  remove_test_topic "long_filename_test"
}

# Test special characters in filenames
test_special_characters() {
  create_test_topic "special_chars_test" false false false
  
  # Create files with special characters
  echo "content" > "$DOTFILES_ROOT/special_chars_test/file with spaces.symlink" 2>/dev/null || true
  echo "content" > "$DOTFILES_ROOT/special_chars_test/file-with-unicode-=%.symlink" 2>/dev/null || true
  echo "content" > "$DOTFILES_ROOT/special_chars_test/file\$with\$dollars.symlink" 2>/dev/null || true
  
  # Run bootstrap
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  
  # Should handle special characters gracefully
  assert_contains "$output" "Bootstrap complete" "Should handle special characters"
  
  # Check if symlinks were created (some may fail due to filesystem limitations)
  if [ -e "$HOME/.file with spaces" ]; then
    test_success "Spaces in filename handled correctly"
  else
    test_warning "Spaces in filename caused issues (may be filesystem limitation)"
  fi
  
  remove_test_topic "special_chars_test"
}

# Test disk space exhaustion simulation
test_disk_space_handling() {
  # This is a simulation - we can't actually exhaust disk space in tests
  # Instead, we test behavior when writes might fail
  
  create_test_topic "disk_space_test" false true false
  
  # Try to create symlink to a non-writable location
  local readonly_target="$TEST_TEMP_DIR/readonly_target"
  mkdir -p "$(dirname "$readonly_target")"
  touch "$readonly_target"
  chmod 444 "$readonly_target"
  
  # Create symlink file pointing to readonly location
  echo "content" > "$DOTFILES_ROOT/disk_space_test/readonly.symlink"
  
  # Run bootstrap - should handle failures gracefully
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  
  # Should complete even if some operations fail
  assert_contains "$output" "Bootstrap complete" "Should complete despite write failures"
  
  remove_test_topic "disk_space_test"
}

# Test concurrent modification during installation
test_concurrent_modification() {
  create_test_topic "concurrent_mod_test" true false false
  
  # Start installation in background
  "$DOTFILES_ROOT/core/commands/install" >/dev/null 2>&1 &
  local install_pid=$!
  
  # While it's running, try to modify the topic
  sleep 0.5  # Give install time to start
  echo "modified during install" > "$DOTFILES_ROOT/concurrent_mod_test/new_file.txt" || true
  
  # Wait for installation to complete
  wait $install_pid
  local install_result=$?
  
  # Installation should still succeed
  assert_equals "0" "$install_result" "Installation should succeed despite concurrent modification"
  
  remove_test_topic "concurrent_mod_test"
}

# Test memory exhaustion with many topics
test_many_topics_performance() {
  local topic_count=50
  local start_time=$(date +%s)
  
  # Create many topics
  for i in $(seq 1 $topic_count); do
    create_test_topic "perf_topic_$i" true false false
  done
  
  # Run install
  local output=$("$DOTFILES_ROOT/core/commands/install" 2>&1)
  local exit_code=$?
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Should complete successfully
  assert_equals "0" "$exit_code" "Should install many topics successfully"
  
  # Should complete in reasonable time (less than 30 seconds)
  if [ $duration -lt 30 ]; then
    test_success "Performance test completed in $duration seconds (acceptable)"
  else
    test_warning "Performance test took $duration seconds (may be slow)"
  fi
  
  # Count successful installations
  local success_count=$(echo "$output" | grep -c "installed successfully" || echo "0")
  assert_equals "$topic_count" "$success_count" "All topics should install successfully"
  
  # Clean up
  for i in $(seq 1 $topic_count); do
    remove_test_topic "perf_topic_$i"
  done
}

# Test interruption handling (SIGINT)
test_interruption_handling() {
  create_test_topic "interrupt_test" true false false
  
  # Add delay to installer to allow interruption
  cat > "$DOTFILES_ROOT/interrupt_test/install.sh" << 'EOF'
#!/usr/bin/env bash
set -e
TOPIC_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$TOPIC_DIR")"
CORE_DIR="$DOTFILES_ROOT/core"
source "$CORE_DIR/lib/common.sh"

info "Installing interrupt test..."
sleep 3  # Allow time for interruption
success "Interrupt test completed"
EOF
  chmod +x "$DOTFILES_ROOT/interrupt_test/install.sh"
  
  # Start installation
  "$DOTFILES_ROOT/core/commands/install" >/dev/null 2>&1 &
  local install_pid=$!
  
  # Interrupt it after a short delay
  sleep 1
  kill -INT $install_pid 2>/dev/null || true
  
  # Wait for process to finish
  wait $install_pid 2>/dev/null || true
  local exit_code=$?
  
  # Process should have been interrupted
  if [ $exit_code -ne 0 ]; then
    test_success "Installation correctly handled interruption"
  else
    test_warning "Installation may not have been properly interrupted"
  fi
  
  remove_test_topic "interrupt_test"
}

# Test malformed topic structures
test_malformed_topics() {
  # Create topic with malformed install.sh
  mkdir -p "$DOTFILES_ROOT/malformed_topic"
  echo "not a valid shell script" > "$DOTFILES_ROOT/malformed_topic/install.sh"
  # Note: Not making it executable to test another failure mode
  
  # Create topic with circular symlink
  create_test_topic "circular_topic" false true false
  ln -sf "$HOME/.testrc" "$DOTFILES_ROOT/circular_topic/circular.symlink" 2>/dev/null || true
  
  # Run install
  local output=$("$DOTFILES_ROOT/core/commands/install" 2>&1)
  local exit_code=$?
  
  # Should handle malformed topics gracefully
  assert_equals "1" "$exit_code" "Should exit with error code due to failures"
  assert_contains "$output" "malformed_topic" "Should attempt to process malformed topic"
  
  # Clean up
  rm -rf "$DOTFILES_ROOT/malformed_topic"
  remove_test_topic "circular_topic"
}

# Test file system case sensitivity issues
test_case_sensitivity() {
  create_test_topic "case_test" false true false
  
  # Create files that might conflict on case-insensitive filesystems
  echo "lowercase" > "$DOTFILES_ROOT/case_test/testfile.symlink"
  echo "uppercase" > "$DOTFILES_ROOT/case_test/TESTFILE.symlink" 2>/dev/null || true
  
  # Run bootstrap
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  
  # Should handle case issues gracefully
  assert_contains "$output" "Bootstrap complete" "Should complete despite case sensitivity issues"
  
  remove_test_topic "case_test"
}

# Test command injection through filenames
test_command_injection() {
  create_test_topic "injection_test" false false false
  
  # Try to create files with command injection attempts
  touch "$DOTFILES_ROOT/injection_test/\$(rm -rf /).symlink" 2>/dev/null || true
  touch "$DOTFILES_ROOT/injection_test/\`evil command\`.symlink" 2>/dev/null || true
  touch "$DOTFILES_ROOT/injection_test/file;rm -rf ~.symlink" 2>/dev/null || true
  
  # Run bootstrap
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  
  # Should complete without executing injected commands
  assert_contains "$output" "Bootstrap complete" "Should complete safely"
  
  # Verify that home directory still exists (wasn't deleted by injection)
  assert_directory_exists "$HOME" "Home directory should still exist (no command injection)"
  
  remove_test_topic "injection_test"
}

# Main test runner for security and edge cases
main() {
  setup_test_environment
  
  run_test "Security: Path Traversal Protection" test_path_traversal_protection
  run_test "Edge Case: Broken Symlinks Recovery" test_broken_symlinks_recovery
  run_test "Edge Case: Permission Failures" test_permission_failures
  run_test "Edge Case: Long Filenames" test_long_filenames
  run_test "Edge Case: Special Characters" test_special_characters
  run_test "Edge Case: Disk Space Handling" test_disk_space_handling
  run_test "Edge Case: Concurrent Modification" test_concurrent_modification
  run_test "Performance: Many Topics" test_many_topics_performance
  run_test "Edge Case: Interruption Handling" test_interruption_handling
  run_test "Edge Case: Malformed Topics" test_malformed_topics
  run_test "Edge Case: Case Sensitivity" test_case_sensitivity
  run_test "Security: Command Injection" test_command_injection
  
  generate_test_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi