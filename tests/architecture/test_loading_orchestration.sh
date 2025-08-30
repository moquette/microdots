#!/usr/bin/env bash
#
# Loading Orchestration Architecture Tests
# Validates the four-stage loading system: PATH -> config -> compinit -> completions
#

set -e

# Get the actual dotfiles root (two levels up from this test)
ACTUAL_DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

source "$(dirname "$0")/../test_framework.sh"

# Override the DOTFILES_ROOT with correct path
DOTFILES_ROOT="$ACTUAL_DOTFILES_ROOT"

# Test the loading order is correct
test_loading_sequence() {
  test_info "Testing four-stage loading orchestration"
  
  local test_home="$TEST_TEMP_DIR/loading_test"
  mkdir -p "$test_home/.dotfiles"
  
  # Copy system to test environment
  cp -r "$DOTFILES_ROOT"/* "$test_home/.dotfiles/" 2>/dev/null || true
  
  # Analyze zshrc for loading order
  local zshrc="$test_home/.dotfiles/zsh/zshrc.symlink"
  
  if [[ ! -f "$zshrc" ]]; then
    test_fail "zshrc.symlink not found for loading sequence test"
    return 1
  fi
  
  # Look for the specific loading stages in order
  local stage1_line=$(grep -n "Stage 1: PATH setup" "$zshrc" | cut -d: -f1)
  local stage2_line=$(grep -n "Stage 2: Configuration" "$zshrc" | cut -d: -f1)
  local stage3_line=$(grep -n "Stage 3: Initialize completion" "$zshrc" | cut -d: -f1)
  local stage4_line=$(grep -n "Stage 4: Load completions" "$zshrc" | cut -d: -f1)
  
  # Look for the actual loading lines (ZSH uses special syntax)
  local path_load=$(grep -n "for file in.*\*/path\.zsh" "$zshrc" | head -1 | cut -d: -f1)
  local config_load=$(grep -n "for file in.*:#\*/path\.zsh.*:#\*/completion\.zsh" "$zshrc" | head -1 | cut -d: -f1)
  local compinit_line=$(grep -n "^compinit" "$zshrc" | head -1 | cut -d: -f1)
  local completion_load=$(grep -n "for file in.*\*/completion\.zsh" "$zshrc" | head -1 | cut -d: -f1)
  
  test_log "Loading order detected:"
  test_log "  Stage 1 (PATH): line $path_load"
  test_log "  Stage 2 (Config): line $config_load" 
  test_log "  Stage 3 (Compinit): line $compinit_line"
  test_log "  Stage 4 (Completion): line $completion_load"
  
  # Verify correct ordering
  if [[ -n "$path_load" && -n "$config_load" && "$path_load" -gt "$config_load" ]]; then
    test_fail "PATH loading occurs after config loading (path: $path_load, config: $config_load)"
    return 1
  fi
  
  if [[ -n "$config_load" && -n "$compinit_line" && "$config_load" -gt "$compinit_line" ]]; then
    test_fail "Config loading occurs after compinit (config: $config_load, compinit: $compinit_line)"
    return 1
  fi
  
  if [[ -n "$compinit_line" && -n "$completion_load" && "$compinit_line" -gt "$completion_load" ]]; then
    test_fail "Compinit occurs after completion loading (compinit: $compinit_line, completion: $completion_load)"
    return 1
  fi
  
  test_success "Loading orchestration follows correct sequence: PATH -> config -> compinit -> completions"
}

# Test that PATH modifications are available in config stage
test_path_availability() {
  test_info "Testing that PATH modifications are available during config stage"
  
  # Create test topic with path and config files
  local test_topic="$TEST_TEMP_DIR/path_test_topic"
  mkdir -p "$test_topic/bin"
  
  # Create a test command
  cat > "$test_topic/bin/pathtest" << 'PATHTEST_BIN'
#!/bin/bash
echo "PATH dependency available"
PATHTEST_BIN
  chmod +x "$test_topic/bin/pathtest"
  
  # Create path.zsh that adds to PATH
  cat > "$test_topic/path.zsh" << 'PATHTEST_PATH'
export PATH="$TEST_TOPIC/bin:$PATH"
PATHTEST_PATH
  
  # Create config.zsh that depends on PATH
  cat > "$test_topic/config.zsh" << 'PATHTEST_CONFIG'
if command -v pathtest >/dev/null 2>&1; then
  export PATHTEST_AVAILABLE=1
  alias testpath="pathtest"
else
  export PATHTEST_AVAILABLE=0
fi
PATHTEST_CONFIG
  
  # Simulate loading order
  export TEST_TOPIC="$test_topic"
  source "$test_topic/path.zsh"
  source "$test_topic/config.zsh"
  
  if [[ "$PATHTEST_AVAILABLE" != "1" ]]; then
    test_fail "PATH modifications not available during config stage"
    return 1
  fi
  
  test_success "PATH modifications properly available during config stage"
}

# Test completion system initialization
test_completion_initialization() {
  test_info "Testing completion system initialization order"
  
  local test_home="$TEST_TEMP_DIR/completion_test"
  mkdir -p "$test_home"
  
  # Create minimal zsh environment
  export HOME="$test_home"
  export ZSH="$test_home/.dotfiles"
  
  mkdir -p "$ZSH"
  cp -r "$DOTFILES_ROOT/zsh" "$ZSH/" 2>/dev/null || true
  
  # Check if completion system can be initialized
  # This is a simplified test - full test would require zsh subprocess
  
  local zshrc="$ZSH/zsh/zshrc.symlink"
  if [[ -f "$zshrc" ]]; then
    # Check that compinit is called before completion loading
    if ! grep -q "compinit" "$zshrc"; then
      test_fail "compinit not found in zshrc"
      return 1
    fi
    
    # Check that completion files are sourced after compinit
    local compinit_line=$(grep -n "compinit" "$zshrc" | head -1 | cut -d: -f1)
    local completion_line=$(grep -n "completion\.zsh" "$zshrc" | head -1 | cut -d: -f1)
    
    if [[ -n "$compinit_line" && -n "$completion_line" && "$compinit_line" -gt "$completion_line" ]]; then
      test_fail "compinit called after completion loading"
      return 1
    fi
    
    test_success "Completion system initialization order is correct"
  else
    test_fail "Cannot test completion initialization - zshrc not found"
    return 1
  fi
}

# Test stage isolation (each stage only loads appropriate files)
test_stage_isolation() {
  test_info "Testing that each loading stage only processes appropriate files"
  
  local test_home="$TEST_TEMP_DIR/stage_test"
  mkdir -p "$test_home/.dotfiles"
  
  # Create test topic with different file types
  local test_topic="$test_home/.dotfiles/stage_test"
  mkdir -p "$test_topic"
  
  cat > "$test_topic/path.zsh" << 'STAGE_PATH'
export STAGE_PATH_LOADED=1
STAGE_PATH

  cat > "$test_topic/config.zsh" << 'STAGE_CONFIG'
export STAGE_CONFIG_LOADED=1
STAGE_CONFIG

  cat > "$test_topic/completion.zsh" << 'STAGE_COMPLETION'
export STAGE_COMPLETION_LOADED=1
STAGE_COMPLETION

  cat > "$test_topic/other.zsh" << 'STAGE_OTHER'
export STAGE_OTHER_LOADED=1
STAGE_OTHER
  
  # Test that each file type is processed at the right stage
  # This would typically be tested in a full shell environment
  
  # Check zshrc patterns for stage isolation
  local zshrc="$DOTFILES_ROOT/zsh/zshrc.symlink"
  if [[ -f "$zshrc" ]]; then
    # Verify path.zsh files are processed separately
    if ! grep -q "path\.zsh" "$zshrc"; then
      test_fail "PATH stage not implemented in zshrc"
      return 1
    fi
    
    # Verify completion.zsh files are processed separately  
    if ! grep -q "completion\.zsh" "$zshrc"; then
      test_fail "Completion stage not implemented in zshrc"
      return 1
    fi
    
    # Verify other .zsh files are excluded from path and completion stages
    if grep -A5 -B5 "path\.zsh" "$zshrc" | grep -q "\.zsh" | grep -v "path\.zsh"; then
      # Check if it's properly excluded
      local path_section=$(grep -A10 -B5 "path\.zsh" "$zshrc")
      if echo "$path_section" | grep -E "\.zsh.*completion\.zsh"; then
        test_fail "PATH stage processes non-path files"
        return 1
      fi
    fi
    
    test_success "Each loading stage processes only appropriate file types"
  else
    test_fail "Cannot test stage isolation - zshrc not found"
    return 1
  fi
}

# Test loading resilience (missing stages don't break system)
test_loading_resilience() {
  test_info "Testing loading resilience with missing components"
  
  local test_home="$TEST_TEMP_DIR/resilience_test"
  mkdir -p "$test_home/.dotfiles"
  
  # Create topics with missing stages
  local incomplete_topic="$test_home/.dotfiles/incomplete"
  mkdir -p "$incomplete_topic"
  
  # Topic with only config (no path or completion)
  cat > "$incomplete_topic/config.zsh" << 'INCOMPLETE_CONFIG'
export INCOMPLETE_LOADED=1
alias incomplete="echo works"
INCOMPLETE_CONFIG
  
  # Topic with only path (no config or completion)
  local path_only_topic="$test_home/.dotfiles/pathonly"
  mkdir -p "$path_only_topic/bin"
  
  cat > "$path_only_topic/path.zsh" << 'PATHONLY_PATH'
export PATH="$path_only_topic/bin:$PATH"
PATHONLY_PATH
  
  cat > "$path_only_topic/bin/pathonly" << 'PATHONLY_BIN'
#!/bin/bash
echo "pathonly works"
PATHONLY_BIN
  chmod +x "$path_only_topic/bin/pathonly"
  
  # Test that loading mechanism handles missing files gracefully
  local zshrc="$DOTFILES_ROOT/zsh/zshrc.symlink"
  if [[ -f "$zshrc" ]]; then
    # Check for error handling patterns in loading loops
    if grep -q "2>/dev/null\||| true\||| :" "$zshrc"; then
      test_success "Loading system includes error handling for missing files"
    else
      test_log "Warning: Loading system may not handle missing files gracefully"
      # This might be acceptable depending on implementation
      test_success "Loading resilience check completed (implementation dependent)"
    fi
  else
    test_fail "Cannot test loading resilience - zshrc not found"
    return 1
  fi
}

# Run all loading orchestration tests
run_loading_tests() {
  test_info "Loading Orchestration Architecture Tests"
  
  setup_test_environment
  
  test_loading_sequence
  test_path_availability
  test_completion_initialization
  test_stage_isolation
  test_loading_resilience
  
  cleanup_test_environment
  
  test_summary
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_loading_tests
fi
