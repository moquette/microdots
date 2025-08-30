#!/usr/bin/env bash
#
# Unit Tests for Core Functions (common.sh)
# Tests all shared utility functions
#

# Source the test framework
TEST_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
source "$TEST_DIR/test_framework.sh"

# Source the functions under test
source "$DOTFILES_ROOT/core/lib/common.sh"

# Test get_dotfiles_root function
test_get_dotfiles_root() {
  # Should find dotfiles root from any subdirectory
  local result=$(get_dotfiles_root)
  assert_equals "$DOTFILES_ROOT" "$result" "get_dotfiles_root should return correct path"
  
  # Test from a nested directory
  mkdir -p "$TEST_TEMP_DIR/nested/deeply"
  cd "$TEST_TEMP_DIR/nested/deeply"
  
  # Create a mock structure
  mkdir -p "$TEST_TEMP_DIR/mock_dotfiles/core"
  touch "$TEST_TEMP_DIR/mock_dotfiles/core/dots"
  
  # Should fail if no dotfiles root found
  local result2=$(get_dotfiles_root 2>/dev/null || echo "NOT_FOUND")
  assert_equals "NOT_FOUND" "$result2" "get_dotfiles_root should fail when no root found"
  
  cd "$DOTFILES_ROOT"
}

# Test output functions
test_output_functions() {
  # Capture output of each function
  local info_output=$(info "test message" 2>&1)
  local success_output=$(success "test success" 2>&1)
  local warning_output=$(warning "test warning" 2>&1)
  local error_output=$(error "test error" 2>&1)
  
  # Check that output contains expected text
  assert_contains "$info_output" "test message" "info function should output message"
  assert_contains "$success_output" "test success" "success function should output message"
  assert_contains "$warning_output" "test warning" "warning function should output message"
  assert_contains "$error_output" "test error" "error function should output message"
  
  # Check for color codes (basic check)
  assert_contains "$success_output" "" "success function should include checkmark"
  assert_contains "$warning_output" " " "warning function should include warning symbol"
  assert_contains "$error_output" "" "error function should include error symbol"
}

# Test create_symlink function
test_create_symlink() {
  # Create test files
  local test_src="$TEST_TEMP_DIR/test_source.txt"
  local test_dst="$TEST_TEMP_DIR/test_destination.txt"
  
  echo "test content" > "$test_src"
  
  # Test successful symlink creation
  if create_symlink "$test_src" "$test_dst" "test symlink" >/dev/null 2>&1; then
    test_success "create_symlink returned success"
  else
    test_error "create_symlink failed"
  fi
  
  assert_symlink_valid "$test_dst" "Created symlink should be valid"
  
  # Test overwriting existing symlink
  echo "new content" > "$test_src"
  if create_symlink "$test_src" "$test_dst" "test overwrite" >/dev/null 2>&1; then
    test_success "create_symlink overwrote existing symlink"
  else
    test_error "create_symlink failed to overwrite"
  fi
  
  assert_symlink_valid "$test_dst" "Overwritten symlink should still be valid"
}

# Test verify_symlink function
test_verify_symlink() {
  local test_src="$TEST_TEMP_DIR/verify_source.txt"
  local test_link="$TEST_TEMP_DIR/verify_link.txt"
  local broken_link="$TEST_TEMP_DIR/broken_link.txt"
  
  echo "content" > "$test_src"
  ln -s "$test_src" "$test_link"
  ln -s "/nonexistent/file" "$broken_link"
  
  # Test valid symlink
  if verify_symlink "$test_link"; then
    test_success "verify_symlink correctly identified valid symlink"
  else
    test_error "verify_symlink failed on valid symlink"
  fi
  
  # Test broken symlink
  if ! verify_symlink "$broken_link"; then
    test_success "verify_symlink correctly identified broken symlink"
  else
    test_error "verify_symlink incorrectly validated broken symlink"
  fi
  
  # Test non-existent file
  if ! verify_symlink "/nonexistent/path"; then
    test_success "verify_symlink correctly rejected non-existent file"
  else
    test_error "verify_symlink incorrectly validated non-existent file"
  fi
}

# Test clean_broken_symlinks function
test_clean_broken_symlinks() {
  local test_dir="$TEST_TEMP_DIR/symlink_test"
  mkdir -p "$test_dir"
  
  # Create valid and broken symlinks
  echo "content" > "$test_dir/source.txt"
  ln -s "$test_dir/source.txt" "$test_dir/valid_link"
  ln -s "/nonexistent" "$test_dir/broken_link"
  ln -s "/also/nonexistent" "$test_dir/also_broken"
  
  # Count before cleanup
  local before_count=$(find "$test_dir" -type l | wc -l)
  assert_equals "3" "$(echo "$before_count" | tr -d ' ')" "Should have 3 symlinks before cleanup"
  
  # Clean broken symlinks
  clean_broken_symlinks "$test_dir"
  
  # Count after cleanup
  local after_count=$(find "$test_dir" -type l | wc -l)
  assert_equals "1" "$(echo "$after_count" | tr -d ' ')" "Should have 1 symlink after cleanup"
  
  # Verify the remaining symlink is valid
  assert_symlink_valid "$test_dir/valid_link" "Remaining symlink should be valid"
  assert_file_not_exists "$test_dir/broken_link" "Broken symlink should be removed"
}

# Test ensure_directory function
test_ensure_directory() {
  local test_dir="$TEST_TEMP_DIR/ensure_test/nested/deep"
  
  # Directory shouldn't exist initially
  assert_file_not_exists "$test_dir" "Test directory should not exist initially"
  
  # Create the directory
  ensure_directory "$test_dir"
  
  # Directory should exist now
  assert_directory_exists "$test_dir" "Directory should exist after ensure_directory"
  
  # Running again should not fail
  ensure_directory "$test_dir"
  assert_directory_exists "$test_dir" "Directory should still exist after second call"
}

# Test count_files function
test_count_files() {
  local test_dir="$TEST_TEMP_DIR/count_test"
  mkdir -p "$test_dir"
  
  # Test empty directory
  local empty_count=$(count_files "$test_dir" "*.txt")
  assert_equals "0" "$empty_count" "Empty directory should have 0 matching files"
  
  # Create some files
  touch "$test_dir/file1.txt"
  touch "$test_dir/file2.txt"
  touch "$test_dir/file3.log"
  touch "$test_dir/another.txt"
  
  # Test counting
  local txt_count=$(count_files "$test_dir" "*.txt")
  assert_equals "3" "$txt_count" "Should count 3 .txt files"
  
  local log_count=$(count_files "$test_dir" "*.log")
  assert_equals "1" "$log_count" "Should count 1 .log file"
  
  local all_count=$(count_files "$test_dir" "*")
  assert_equals "4" "$all_count" "Should count 4 total files"
  
  # Test non-existent directory
  local nonexistent_count=$(count_files "/nonexistent" "*.txt")
  assert_equals "0" "$nonexistent_count" "Non-existent directory should return 0"
}

# Test has_files function
test_has_files() {
  local test_dir="$TEST_TEMP_DIR/has_files_test"
  mkdir -p "$test_dir"
  
  # Test empty directory
  if ! has_files "$test_dir" "*.txt"; then
    test_success "Empty directory correctly reports no files"
  else
    test_error "Empty directory incorrectly reports having files"
  fi
  
  # Add a file
  touch "$test_dir/test.txt"
  
  if has_files "$test_dir" "*.txt"; then
    test_success "Directory with files correctly reports having files"
  else
    test_error "Directory with files incorrectly reports no files"
  fi
  
  # Test different pattern
  if ! has_files "$test_dir" "*.log"; then
    test_success "Directory correctly reports no matching files for different pattern"
  else
    test_error "Directory incorrectly reports having non-matching files"
  fi
}

# Test process_files function
test_process_files() {
  local source_dir="$TEST_TEMP_DIR/process_source"
  local target_dir="$TEST_TEMP_DIR/process_target"
  
  mkdir -p "$source_dir"
  
  # Create test files
  echo "content1" > "$source_dir/file1.md"
  echo "content2" > "$source_dir/file2.md"
  echo "content3" > "$source_dir/other.txt"
  
  # Process .md files
  local results=$(process_files "$source_dir" "$target_dir" "*.md" | tail -1)
  local success_count=$(echo "$results" | awk '{print $1}')
  local fail_count=$(echo "$results" | awk '{print $2}')
  
  assert_equals "2" "$success_count" "Should process 2 .md files successfully"
  assert_equals "0" "$fail_count" "Should have 0 failures"
  
  # Verify symlinks were created
  assert_directory_exists "$target_dir" "Target directory should exist"
  assert_symlink_valid "$target_dir/file1.md" "file1.md symlink should be valid"
  assert_symlink_valid "$target_dir/file2.md" "file2.md symlink should be valid"
  assert_file_not_exists "$target_dir/other.txt" "Non-matching file should not be processed"
  
  # Test with broken source (should handle gracefully)
  rm "$source_dir/file1.md"
  local results2=$(process_files "$source_dir" "$target_dir" "*.md" | tail -1)
  local success_count2=$(echo "$results2" | awk '{print $1}')
  
  # Should still process the remaining file
  assert_equals "1" "$success_count2" "Should process remaining file after source removal"
}

# Test get_topic_name function
test_get_topic_name() {
  local result1=$(get_topic_name "/path/to/my-topic")
  assert_equals "my-topic" "$result1" "Should extract topic name from path"
  
  local result2=$(get_topic_name "/complex/path/with/many/levels/final-topic")
  assert_equals "final-topic" "$result2" "Should extract final component from complex path"
  
  local result3=$(get_topic_name "relative-topic")
  assert_equals "relative-topic" "$result3" "Should handle relative paths"
}

# Main test runner for this file
main() {
  setup_test_environment
  
  run_test "Core: get_dotfiles_root" test_get_dotfiles_root
  run_test "Core: Output Functions" test_output_functions  
  run_test "Core: create_symlink" test_create_symlink
  run_test "Core: verify_symlink" test_verify_symlink
  run_test "Core: clean_broken_symlinks" test_clean_broken_symlinks
  run_test "Core: ensure_directory" test_ensure_directory
  run_test "Core: count_files" test_count_files
  run_test "Core: has_files" test_has_files
  run_test "Core: process_files" test_process_files
  run_test "Core: get_topic_name" test_get_topic_name
  
  generate_test_report
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi