#!/usr/bin/env bash
#
# Test Framework for Modular Dotfiles Architecture
# Bulletproof testing system using bats-compatible syntax
#

set -e

# Test framework configuration
TEST_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$TEST_ROOT")"
TEST_TEMP_DIR="/tmp/dotfiles_test_$$"
TEST_HOME="$TEST_TEMP_DIR/home"
ORIGINAL_HOME="$HOME"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test state tracking
CURRENT_TEST=""
TEST_FAILED=false
SETUP_COMPLETED=false

# Logging functions
test_log() {
  # Ensure directory exists before logging
  if [[ -n "$TEST_TEMP_DIR" ]]; then
    mkdir -p "$TEST_TEMP_DIR" 2>/dev/null || true
    echo "[$CURRENT_TEST] $1" >> "$TEST_TEMP_DIR/test.log" 2>/dev/null || true
  fi
}

test_info() {
  echo -e "${BLUE}INFO:${NC} $1"
  test_log "INFO: $1"
}

test_success() {
  echo -e "${GREEN}${NC} $1"
  test_log "SUCCESS: $1"
}

test_warning() {
  echo -e "${YELLOW}�${NC} $1"
  test_log "WARNING: $1"
}

test_error() {
  echo -e "${RED}${NC} $1"
  test_log "ERROR: $1"
  TEST_FAILED=true
}

# Test setup and teardown
setup_test_environment() {
  test_info "Setting up test environment..."
  
  # Create isolated test environment
  rm -rf "$TEST_TEMP_DIR"
  mkdir -p "$TEST_TEMP_DIR"
  mkdir -p "$TEST_HOME"
  
  # Create test log
  touch "$TEST_TEMP_DIR/test.log"
  
  # Set isolated HOME for tests
  export HOME="$TEST_HOME"
  export DOTFILES_ROOT="$DOTFILES_ROOT"
  
  # Create fake git config to avoid prompts
  git config --global user.name "Test User" 2>/dev/null || true
  git config --global user.email "test@example.com" 2>/dev/null || true
  
  SETUP_COMPLETED=true
  test_success "Test environment ready at $TEST_TEMP_DIR"
}

teardown_test_environment() {
  if [ "$SETUP_COMPLETED" = true ]; then
    test_info "Cleaning up test environment..."
    
    # Restore original HOME
    export HOME="$ORIGINAL_HOME"
    
    # Clean up temp directory
    rm -rf "$TEST_TEMP_DIR"
    
    test_success "Test environment cleaned up"
  fi
}

# Test assertion functions
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"
  
  if [ "$expected" = "$actual" ]; then
    test_success "$message: Expected '$expected', got '$actual'"
  else
    test_error "$message: Expected '$expected', got '$actual'"
  fi
}

assert_not_equals() {
  local not_expected="$1"
  local actual="$2"
  local message="$3"
  
  if [ "$not_expected" != "$actual" ]; then
    test_success "$message: Got '$actual' (not '$not_expected')"
  else
    test_error "$message: Got unexpected value '$actual'"
  fi
}

assert_file_exists() {
  local file="$1"
  local message="$2"
  
  if [ -e "$file" ]; then
    test_success "$message: File exists at $file"
  else
    test_error "$message: File does not exist at $file"
  fi
}

assert_file_not_exists() {
  local file="$1"
  local message="$2"
  
  if [ ! -e "$file" ]; then
    test_success "$message: File correctly does not exist at $file"
  else
    test_error "$message: File unexpectedly exists at $file"
  fi
}

assert_symlink_valid() {
  local link="$1"
  local message="$2"
  
  if [ -L "$link" ] && [ -e "$link" ]; then
    local target=$(readlink "$link")
    test_success "$message: Valid symlink $link -> $target"
  else
    test_error "$message: Invalid or broken symlink at $link"
  fi
}

assert_command_succeeds() {
  local command="$1"
  local message="$2"
  
  if eval "$command" >/dev/null 2>&1; then
    test_success "$message: Command succeeded: $command"
  else
    test_error "$message: Command failed: $command"
  fi
}

assert_command_fails() {
  local command="$1"
  local message="$2"
  
  if ! eval "$command" >/dev/null 2>&1; then
    test_success "$message: Command correctly failed: $command"
  else
    test_error "$message: Command unexpectedly succeeded: $command"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"
  
  if echo "$haystack" | grep -q "$needle"; then
    test_success "$message: Found '$needle' in content"
  else
    test_error "$message: Did not find '$needle' in content"
  fi
}

assert_directory_exists() {
  local dir="$1"
  local message="$2"
  
  if [ -d "$dir" ]; then
    test_success "$message: Directory exists at $dir"
  else
    test_error "$message: Directory does not exist at $dir"
  fi
}

assert_executable() {
  local file="$1"
  local message="$2"
  
  if [ -x "$file" ]; then
    test_success "$message: File is executable: $file"
  else
    test_error "$message: File is not executable: $file"
  fi
}

# Test runner functions
run_test() {
  local test_name="$1"
  local test_function="$2"
  
  CURRENT_TEST="$test_name"
  TEST_FAILED=false
  TESTS_RUN=$((TESTS_RUN + 1))
  
  echo ""
  echo ""
  echo "Running: $test_name"
  echo ""
  
  # Run the test function
  if $test_function; then
    if [ "$TEST_FAILED" = false ]; then
      test_success "Test passed: $test_name"
      TESTS_PASSED=$((TESTS_PASSED + 1))
    else
      test_error "Test failed: $test_name"
      TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
  else
    test_error "Test crashed: $test_name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

skip_test() {
  local test_name="$1"
  local reason="$2"
  
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  test_warning "Skipping test: $test_name ($reason)"
}

# Test report generation
generate_test_report() {
  echo ""
  echo ""
  echo "TEST SUMMARY"
  echo ""
  echo "Tests Run:    $TESTS_RUN"
  echo "Tests Passed: $TESTS_PASSED"
  echo "Tests Failed: $TESTS_FAILED"
  echo "Tests Skipped: $TESTS_SKIPPED"
  echo ""
  
  if [ $TESTS_FAILED -eq 0 ]; then
    test_success "All tests passed!"
    echo ""
    echo "Test log available at: $TEST_TEMP_DIR/test.log"
    return 0
  else
    test_error "$TESTS_FAILED test(s) failed!"
    echo ""
    echo "Test log available at: $TEST_TEMP_DIR/test.log"
    echo "Failure details:"
    grep "ERROR:" "$TEST_TEMP_DIR/test.log" | tail -10
    return 1
  fi
}

# Utility functions for tests
create_test_topic() {
  local topic_name="$1"
  local has_installer="${2:-false}"
  local has_symlinks="${3:-false}"
  local has_zsh="${4:-false}"
  
  local topic_dir="$DOTFILES_ROOT/$topic_name"
  mkdir -p "$topic_dir"
  
  if [ "$has_installer" = true ]; then
    cat > "$topic_dir/install.sh" << 'EOF'
#!/usr/bin/env bash
set -e

TOPIC_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$TOPIC_DIR")"
CORE_DIR="$DOTFILES_ROOT/core"

source "$CORE_DIR/lib/common.sh"

info "Installing test topic..."
success "Test topic installed successfully!"
EOF
    chmod +x "$topic_dir/install.sh"
  fi
  
  if [ "$has_symlinks" = true ]; then
    echo "# Test config file" > "$topic_dir/testrc.symlink"
  fi
  
  if [ "$has_zsh" = true ]; then
    echo "# Test ZSH configuration" > "$topic_dir/test.zsh"
    echo "alias testcmd='echo test'" >> "$topic_dir/test.zsh"
  fi
}

remove_test_topic() {
  local topic_name="$1"
  rm -rf "$DOTFILES_ROOT/$topic_name"
}

# Signal handlers for cleanup
cleanup_on_exit() {
  teardown_test_environment
}

trap cleanup_on_exit EXIT INT TERM

# Export functions for use in test files
export -f test_info test_success test_warning test_error
export -f assert_equals assert_not_equals assert_file_exists assert_file_not_exists
export -f assert_symlink_valid assert_command_succeeds assert_command_fails
export -f assert_contains assert_directory_exists assert_executable
export -f create_test_topic remove_test_topic
# Additional test functions for comprehensive test suite

test_fail() {
  echo -e "${RED}FAIL:${NC} $1"
  test_log "FAIL: $1"
  TEST_FAILED=true
  ((TESTS_FAILED++))
}

test_skip() {
  echo -e "${YELLOW}SKIP:${NC} $1"
  test_log "SKIP: $1"
  ((TESTS_SKIPPED++))
}

test_summary() {
  echo
  echo -e "${BOLD}Test Summary:${NC}"
  echo "  Tests run: $TESTS_RUN"
  echo "  Tests passed: $TESTS_PASSED"
  echo "  Tests failed: $TESTS_FAILED"
  echo "  Tests skipped: $TESTS_SKIPPED"
  
  local success_rate=0
  if [[ $TESTS_RUN -gt 0 ]]; then
    success_rate=$(( TESTS_PASSED * 100 / TESTS_RUN ))
  fi
  echo "  Success rate: ${success_rate}%"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    return 0
  else
    echo -e "${RED}Some tests failed!${NC}"
    return 1
  fi
}

cleanup_test_environment() {
  if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
    rm -rf "$TEST_TEMP_DIR" 2>/dev/null || true
  fi
  
  # Reset environment variables
  export HOME="$ORIGINAL_HOME"
  
  test_log "Test environment cleaned up"
}

# Export additional functions
export -f test_fail test_skip test_summary cleanup_test_environment
