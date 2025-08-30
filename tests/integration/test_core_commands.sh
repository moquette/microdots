#!/usr/bin/env bash
#
# Integration Tests for Core Commands (bootstrap, install)
# Tests complete command workflows and interactions
#

# Source the test framework
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$TEST_DIR/test_framework.sh"

# Test bootstrap command basic functionality
test_bootstrap_basic() {
  # Skip git config prompts by pre-creating the file
  mkdir -p "$DOTFILES_ROOT/git"
  cat > "$DOTFILES_ROOT/git/gitconfig.local.symlink" << 'EOF'
[user]
  name = Test User
  email = test@example.com
EOF
  
  # Run bootstrap
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "Bootstrap should exit successfully"
  assert_contains "$output" "gitconfig already configured" "Should detect existing gitconfig"
  assert_contains "$output" "Bootstrap complete" "Should complete successfully"
  
  # Verify symlinks were created for .symlink files
  assert_symlink_valid "$HOME/.vimrc" "vimrc symlink should be created"
  assert_symlink_valid "$HOME/.gitconfig" "gitconfig symlink should be created"
  assert_symlink_valid "$HOME/.zshrc" "zshrc symlink should be created"
  
  # Clean up the pre-created file
  rm -f "$DOTFILES_ROOT/git/gitconfig.local.symlink"
}

# Test bootstrap with --install flag
test_bootstrap_with_install() {
  # Create a minimal test topic that should be installed
  create_test_topic "test_bootstrap_topic" true false false
  
  # Skip git config prompts
  mkdir -p "$DOTFILES_ROOT/git"
  cat > "$DOTFILES_ROOT/git/gitconfig.local.symlink" << 'EOF'
[user]
  name = Test User
  email = test@example.com
EOF
  
  # Run bootstrap with --install
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" --install 2>&1)
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "Bootstrap --install should exit successfully"
  assert_contains "$output" "Running installers" "Should indicate installers are running"
  assert_contains "$output" "test_bootstrap_topic" "Should install the test topic"
  assert_contains "$output" "Installers completed" "Should complete installers"
  
  # Clean up
  remove_test_topic "test_bootstrap_topic"
  rm -f "$DOTFILES_ROOT/git/gitconfig.local.symlink"
}

# Test install command basic functionality
test_install_basic() {
  # Create test topics
  create_test_topic "test_topic_1" true false false
  create_test_topic "test_topic_2" true false false
  create_test_topic "test_topic_3" false true false  # No installer, just symlinks
  
  # Run install
  local output=$("$DOTFILES_ROOT/core/commands/install" 2>&1)
  local exit_code=$?
  
  assert_equals "0" "$exit_code" "Install should exit successfully"
  assert_contains "$output" "Installing test_topic_1" "Should install first topic"
  assert_contains "$output" "Installing test_topic_2" "Should install second topic"
  assert_not_contains "$output" "Installing test_topic_3" "Should skip topic without installer"
  assert_contains "$output" "All dotfiles installed successfully" "Should complete successfully"
  
  # Clean up
  remove_test_topic "test_topic_1"
  remove_test_topic "test_topic_2"
  remove_test_topic "test_topic_3"
}

# Test install command with failures
test_install_with_failures() {
  # Create a topic that will fail
  mkdir -p "$DOTFILES_ROOT/failing_topic"
  cat > "$DOTFILES_ROOT/failing_topic/install.sh" << 'EOF'
#!/usr/bin/env bash
set -e
TOPIC_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$TOPIC_DIR")"
CORE_DIR="$DOTFILES_ROOT/core"
source "$CORE_DIR/lib/common.sh"

info "Installing failing topic..."
exit 1  # Force failure
EOF
  chmod +x "$DOTFILES_ROOT/failing_topic/install.sh"
  
  # Create a successful topic too
  create_test_topic "success_topic" true false false
  
  # Run install (should fail due to failing topic)
  local output=$("$DOTFILES_ROOT/core/commands/install" 2>&1)
  local exit_code=$?
  
  assert_equals "1" "$exit_code" "Install should exit with error code when topics fail"
  assert_contains "$output" "Installing failing_topic" "Should attempt to install failing topic"
  assert_contains "$output" "Failed to install failing_topic" "Should report failure"
  assert_contains "$output" "Installing success_topic" "Should still try other topics"
  assert_contains "$output" "Failed: 1 topics" "Should report failure count"
  
  # Clean up
  remove_test_topic "failing_topic"
  remove_test_topic "success_topic"
}

# Test dynamic discovery pattern
test_dynamic_discovery() {
  local topic_count_before
  local topic_count_after
  
  # Count current topics with installers
  topic_count_before=$(find "$DOTFILES_ROOT" -maxdepth 2 -name "install.sh" -path "$DOTFILES_ROOT/*/install.sh" | wc -l | tr -d ' ')
  
  # Add a new topic dynamically
  create_test_topic "dynamic_topic" true false false
  
  # Count again
  topic_count_after=$(find "$DOTFILES_ROOT" -maxdepth 2 -name "install.sh" -path "$DOTFILES_ROOT/*/install.sh" | wc -l | tr -d ' ')
  
  # Should have discovered one more topic
  local expected_count=$((topic_count_before + 1))
  assert_equals "$expected_count" "$topic_count_after" "Should discover new topic dynamically"
  
  # Run install to make sure it picks up the new topic
  local output=$("$DOTFILES_ROOT/core/commands/install" 2>&1)
  assert_contains "$output" "Installing dynamic_topic" "Should install dynamically added topic"
  
  # Clean up
  remove_test_topic "dynamic_topic"
}

# Test subtopic installation (Claude pattern)
test_subtopic_installation() {
  # Create a topic with subtopics similar to Claude structure
  mkdir -p "$DOTFILES_ROOT/test_parent"
  
  # Main installer that discovers subtopics
  cat > "$DOTFILES_ROOT/test_parent/install.sh" << 'EOF'
#!/usr/bin/env bash
set -e

PARENT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$PARENT_DIR")"
CORE_DIR="$DOTFILES_ROOT/core"

source "$CORE_DIR/lib/common.sh"

info "Installing parent topic..."

# Discover and run subtopic installers
installed_subtopics=0
for subtopic_dir in "$PARENT_DIR"/*/; do
  [ ! -d "$subtopic_dir" ] && continue
  
  subtopic=$(basename "$subtopic_dir")
  
  if [ -f "$subtopic_dir/install.sh" ]; then
    info "Installing subtopic: $subtopic"
    if (cd "$subtopic_dir" && bash ./install.sh); then
      success "Subtopic $subtopic installed"
      installed_subtopics=$((installed_subtopics + 1))
    else
      error "Failed to install subtopic $subtopic"
    fi
  fi
done

success "Parent topic installed with $installed_subtopics subtopic(s)"
EOF
  chmod +x "$DOTFILES_ROOT/test_parent/install.sh"
  
  # Create subtopics
  mkdir -p "$DOTFILES_ROOT/test_parent/sub1"
  cat > "$DOTFILES_ROOT/test_parent/sub1/install.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "Sub1 installed"
EOF
  chmod +x "$DOTFILES_ROOT/test_parent/sub1/install.sh"
  
  mkdir -p "$DOTFILES_ROOT/test_parent/sub2"
  cat > "$DOTFILES_ROOT/test_parent/sub2/install.sh" << 'EOF'
#!/usr/bin/env bash
set -e
echo "Sub2 installed"
EOF
  chmod +x "$DOTFILES_ROOT/test_parent/sub2/install.sh"
  
  # Run install
  local output=$("$DOTFILES_ROOT/core/commands/install" 2>&1)
  
  assert_contains "$output" "Installing test_parent" "Should install parent topic"
  assert_contains "$output" "Installing subtopic: sub1" "Should install subtopic 1"
  assert_contains "$output" "Installing subtopic: sub2" "Should install subtopic 2"
  assert_contains "$output" "Sub1 installed" "Should execute subtopic 1 installer"
  assert_contains "$output" "Sub2 installed" "Should execute subtopic 2 installer"
  assert_contains "$output" "installed with 2 subtopic(s)" "Should report subtopic count"
  
  # Clean up
  rm -rf "$DOTFILES_ROOT/test_parent"
}

# Test symlink creation during bootstrap
test_symlink_creation() {
  # Create test symlink files
  create_test_topic "symlink_topic" false true false
  
  # Add more symlink files
  echo "# Test bashrc" > "$DOTFILES_ROOT/symlink_topic/bashrc.symlink"
  echo "# Test profile" > "$DOTFILES_ROOT/symlink_topic/profile.symlink"
  
  # Run bootstrap to create symlinks
  local output=$("$DOTFILES_ROOT/core/commands/bootstrap" 2>&1)
  
  # Verify symlinks were created
  assert_symlink_valid "$HOME/.testrc" "testrc symlink should be created"
  assert_symlink_valid "$HOME/.bashrc" "bashrc symlink should be created"
  assert_symlink_valid "$HOME/.profile" "profile symlink should be created"
  
  # Check that symlinks point to the right places
  local testrc_target=$(readlink "$HOME/.testrc")
  assert_contains "$testrc_target" "symlink_topic/testrc.symlink" "testrc should point to correct source"
  
  # Clean up
  remove_test_topic "symlink_topic"
}

# Test error handling and recovery
test_error_handling() {
  # Create a topic with syntax error
  mkdir -p "$DOTFILES_ROOT/syntax_error_topic"
  cat > "$DOTFILES_ROOT/syntax_error_topic/install.sh" << 'EOF'
#!/usr/bin/env bash
# This has a syntax error
if [ "incomplete
EOF
  chmod +x "$DOTFILES_ROOT/syntax_error_topic/install.sh"
  
  # Create a normal topic
  create_test_topic "normal_topic" true false false
  
  # Run install
  local output=$("$DOTFILES_ROOT/core/commands/install" 2>&1)
  local exit_code=$?
  
  # Should fail due to syntax error but continue with other topics
  assert_equals "1" "$exit_code" "Should exit with error code"
  assert_contains "$output" "Failed to install syntax_error_topic" "Should report syntax error failure"
  assert_contains "$output" "normal_topic installed successfully" "Should continue with other topics"
  
  # Clean up
  rm -rf "$DOTFILES_ROOT/syntax_error_topic"
  remove_test_topic "normal_topic"
}

# Test CLI wrapper functionality
test_cli_wrapper() {
  # Test help command
  local help_output=$("$DOTFILES_ROOT/core/dots" help 2>&1)
  assert_contains "$help_output" "dots - dotfiles management system" "Help should show description"
  assert_contains "$help_output" "bootstrap" "Help should list bootstrap command"
  assert_contains "$help_output" "install" "Help should list install command"
  
  # Test invalid command
  local invalid_output=$("$DOTFILES_ROOT/core/dots" invalid_command 2>&1)
  local invalid_exit_code=$?
  assert_equals "1" "$invalid_exit_code" "Invalid command should return error code"
  assert_contains "$invalid_output" "Unknown command" "Should report unknown command"
  
  # Test command routing to bootstrap
  create_test_topic "wrapper_test" false true false
  
  # Skip git prompts for this test
  mkdir -p "$DOTFILES_ROOT/git"
  cat > "$DOTFILES_ROOT/git/gitconfig.local.symlink" << 'EOF'
[user]
  name = Test User
  email = test@example.com
EOF
  
  local bootstrap_output=$("$DOTFILES_ROOT/core/dots" bootstrap 2>&1)
  assert_contains "$bootstrap_output" "Bootstrap complete" "CLI should route to bootstrap command"
  
  # Verify symlink was created
  assert_symlink_valid "$HOME/.testrc" "CLI bootstrap should create symlinks"
  
  # Clean up
  remove_test_topic "wrapper_test"
  rm -f "$DOTFILES_ROOT/git/gitconfig.local.symlink"
}

# Test concurrent execution safety
test_concurrent_safety() {
  create_test_topic "concurrent_topic" true false false
  
  # Add a delay to the installer to simulate concurrent access
  cat > "$DOTFILES_ROOT/concurrent_topic/install.sh" << 'EOF'
#!/usr/bin/env bash
set -e
TOPIC_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$TOPIC_DIR")"
CORE_DIR="$DOTFILES_ROOT/core"
source "$CORE_DIR/lib/common.sh"

info "Installing concurrent topic..."
sleep 1  # Small delay to test concurrency
success "Concurrent topic installed successfully!"
EOF
  chmod +x "$DOTFILES_ROOT/concurrent_topic/install.sh"
  
  # Run two install commands simultaneously
  "$DOTFILES_ROOT/core/commands/install" >/dev/null 2>&1 &
  local pid1=$!
  
  "$DOTFILES_ROOT/core/commands/install" >/dev/null 2>&1 &
  local pid2=$!
  
  # Wait for both to complete
  wait $pid1
  local exit1=$?
  wait $pid2
  local exit2=$?
  
  # Both should succeed (no file locking conflicts)
  assert_equals "0" "$exit1" "First concurrent install should succeed"
  assert_equals "0" "$exit2" "Second concurrent install should succeed"
  
  remove_test_topic "concurrent_topic"
}

# Main test runner for integration tests
main() {
  setup_test_environment
  
  run_test "Integration: Bootstrap Basic" test_bootstrap_basic
  run_test "Integration: Bootstrap with Install" test_bootstrap_with_install
  run_test "Integration: Install Basic" test_install_basic
  run_test "Integration: Install with Failures" test_install_with_failures
  run_test "Integration: Dynamic Discovery" test_dynamic_discovery
  run_test "Integration: Subtopic Installation" test_subtopic_installation
  run_test "Integration: Symlink Creation" test_symlink_creation
  run_test "Integration: Error Handling" test_error_handling
  run_test "Integration: CLI Wrapper" test_cli_wrapper
  run_test "Integration: Concurrent Safety" test_concurrent_safety
  
  generate_test_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi