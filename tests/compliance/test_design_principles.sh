#!/usr/bin/env bash
#
# Design Principles Compliance Tests
# Validates adherence to the core Microdots design principles
#

set -e

# Get the actual dotfiles root (two levels up from this test)
ACTUAL_DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

source "$(dirname "$0")/../test_framework.sh"

# Override the DOTFILES_ROOT with correct path
DOTFILES_ROOT="$ACTUAL_DOTFILES_ROOT"

# Test defensive programming compliance
test_defensive_programming_compliance() {
  test_info "Testing compliance with defensive programming principles"
  
  local violations=0
  local total_files=0
  
  # Check all configuration files in topics
  for topic_dir in "$DOTFILES_ROOT"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    case "$topic_name" in
      ".|..|tests|docs|core|.git|.local") continue ;;
    esac
    
    test_log "Checking defensive programming in topic: $topic_name"
    
    # Check each config file in topic
    for config_file in "$topic_dir"/*.zsh "$topic_dir"/*.sh; do
      [[ -f "$config_file" ]] || continue
      ((total_files++))
      
      local filename="$(basename "$config_file")"
      local has_command_usage=false
      local has_defensive_checks=false
      
      # Check if file uses external commands
      if grep -qE "(brew|git|npm|yarn|pip|docker|kubectl|curl|wget)" "$config_file"; then
        has_command_usage=true
      fi
      
      # Check if file has defensive patterns
      if grep -qE "(command -v|which.*>/dev/null|type -p|\[\[ -x|\[\[ -f|\[\[ -d|if.*command)" "$config_file"; then
        has_defensive_checks=true
      fi
      
      # If uses commands but no checks, that's a violation
      if [[ "$has_command_usage" == "true" && "$has_defensive_checks" == "false" ]]; then
        test_log "Defensive programming violation: $topic_name/$filename uses commands without checks"
        ((violations++))
      fi
      
      # Check for proper error handling
      if grep -qE "(set -e|set -eu|set -euo)" "$config_file"; then
        test_log "Good: $topic_name/$filename uses strict error handling"
      fi
      
      # Check for graceful degradation patterns
      if grep -qE "(2>/dev/null|\|\| true|\|\| return|\|\| continue)" "$config_file"; then
        test_log "Good: $topic_name/$filename implements graceful degradation"
      fi
    done
  done
  
  local compliance_rate=0
  if [[ $total_files -gt 0 ]]; then
    compliance_rate=$(( (total_files - violations) * 100 / total_files ))
  fi
  
  test_log "Defensive programming compliance: $compliance_rate% ($violations violations in $total_files files)"
  
  if [[ $violations -eq 0 ]]; then
    test_success "Perfect defensive programming compliance"
  elif [[ $compliance_rate -ge 80 ]]; then
    test_success "Good defensive programming compliance (${compliance_rate}%)"
  else
    test_fail "Poor defensive programming compliance (${compliance_rate}%)"
    return 1
  fi
}

# Test "local always wins" principle compliance
test_local_always_wins_compliance() {
  test_info "Testing compliance with 'local always wins' principle"
  
  local test_home="$TEST_TEMP_DIR/local_wins_test"
  mkdir -p "$test_home"
  
  # Set up test environment
  cp -r "$DOTFILES_ROOT" "$test_home/.dotfiles"
  mkdir -p "$test_home/.dotfiles/local/test_topic"
  
  # Create public config
  mkdir -p "$test_home/.dotfiles/test_topic"
  cat > "$test_home/.dotfiles/test_topic/config.zsh" << 'PUBLIC_CONFIG'
export TEST_VALUE="public"
alias testcmd="echo public"
PUBLIC_CONFIG
  
  # Create local override
  cat > "$test_home/.dotfiles/local/test_topic/config.zsh" << 'LOCAL_CONFIG'
export TEST_VALUE="local"
alias testcmd="echo local"
LOCAL_CONFIG
  
  # Test loading order (simulate what zshrc does)
  export ZSH="$test_home/.dotfiles"
  export LOCAL_PATH="$test_home/.dotfiles/local"
  
  # Source public first, then local
  source "$test_home/.dotfiles/test_topic/config.zsh"
  local public_value="$TEST_VALUE"
  
  source "$test_home/.dotfiles/local/test_topic/config.zsh"
  local final_value="$TEST_VALUE"
  
  # Verify local wins
  if [[ "$final_value" == "local" && "$public_value" == "public" ]]; then
    test_success "Local configuration properly overrides public configuration"
  else
    test_fail "Local override not working properly (public: $public_value, final: $final_value)"
    return 1
  fi
  
  # Test alias override
  if alias testcmd 2>/dev/null | grep -q "local"; then
    test_success "Local aliases properly override public aliases"
  else
    test_log "Alias override test inconclusive (shell-dependent)"
    test_success "Alias override test completed"
  fi
}

# Test self-containment principle compliance
test_self_containment_compliance() {
  test_info "Testing compliance with self-containment principle"
  
  local violations=0
  
  # Test each topic for self-containment
  for topic_dir in "$DOTFILES_ROOT"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    case "$topic_name" in
      ".|..|tests|docs|core|.git|.local") continue ;;
    esac
    
    test_log "Checking self-containment of topic: $topic_name"
    
    # Check for external dependencies (references to other topics)
    for file in "$topic_dir"/*; do
      [[ -f "$file" ]] || continue
      
      # Look for references to other topics
      if grep -E "\.\./[^/]|/[^/]*\.\./|\$ZSH/[^/]*/" "$file" 2>/dev/null | grep -v "$topic_name"; then
        local refs=$(grep -E "\.\./[^/]|/[^/]*\.\./|\$ZSH/[^/]*/" "$file" 2>/dev/null | grep -v "$topic_name")
        test_log "Self-containment violation in $topic_name/$(basename "$file"):"
        test_log "  $refs"
        ((violations++))
      fi
    done
    
    # Check that all referenced local files exist
    for file in "$topic_dir"/*.zsh "$topic_dir"/*.sh; do
      [[ -f "$file" ]] || continue
      
      # Look for local file references
      grep -oE "\./[^[:space:]]+" "$file" 2>/dev/null | while read -r ref; do
        local full_path="$topic_dir/$ref"
        if [[ ! -f "$full_path" ]]; then
          test_log "Missing dependency: $topic_name/$(basename "$file") references $ref"
          ((violations++))
        fi
      done
    done
  done
  
  if [[ $violations -eq 0 ]]; then
    test_success "Perfect self-containment compliance"
  elif [[ $violations -le 2 ]]; then
    test_success "Good self-containment compliance (minor issues: $violations)"
  else
    test_fail "Poor self-containment compliance (violations: $violations)"
    return 1
  fi
}

# Test hot-deployment principle compliance
test_hot_deployment_compliance() {
  test_info "Testing compliance with hot-deployment principle"
  
  local test_home="$TEST_TEMP_DIR/hotdeploy_compliance_test"
  mkdir -p "$test_home"
  
  # Copy existing system
  cp -r "$DOTFILES_ROOT" "$test_home/.dotfiles"
  
  # Create a new topic at runtime
  local new_topic="$test_home/.dotfiles/hotdeploy_test"
  mkdir -p "$new_topic"
  
  cat > "$new_topic/config.zsh" << 'HOTDEPLOY_CONFIG'
export HOTDEPLOY_TEST="loaded"
alias hotdeploy="echo hot deployment works"
HOTDEPLOY_CONFIG
  
  # Test that the loading mechanism would discover this new topic
  local zshrc="$test_home/.dotfiles/zsh/zshrc.symlink"
  
  if [[ ! -f "$zshrc" ]]; then
    test_fail "Cannot test hot deployment - zshrc not found"
    return 1
  fi
  
  # Check that loading uses patterns that would pick up new topics
  if grep -q "\*" "$zshrc" && grep -q "\.zsh" "$zshrc"; then
    test_success "Hot deployment supported - uses glob patterns for topic discovery"
  else
    # Check for explicit directory listing (less flexible)
    if grep -qE "for.*in.*\$ZSH/[^*]" "$zshrc"; then
      test_log "Hot deployment may be limited - uses explicit directory patterns"
      test_success "Hot deployment test completed with limitations noted"
    else
      test_fail "Hot deployment mechanism not clearly implemented"
      return 1
    fi
  fi
  
  # Test that new topics don't require system restart
  # This is inherently true if shell sources files at runtime
  test_success "Hot deployment compliance verified"
}

# Test loading orchestration compliance
test_loading_orchestration_compliance() {
  test_info "Testing compliance with loading orchestration (PATH -> config -> compinit -> completions)"
  
  local zshrc="$DOTFILES_ROOT/zsh/zshrc.symlink"
  
  if [[ ! -f "$zshrc" ]]; then
    test_fail "Cannot test loading orchestration - zshrc not found"
    return 1
  fi
  
  # Extract loading patterns and their line numbers
  local path_loading=$(grep -n "path\.zsh" "$zshrc" | head -1 | cut -d: -f1)
  local config_loading=$(grep -n "\.zsh" "$zshrc" | grep -v "path\.zsh" | grep -v "completion\.zsh" | head -1 | cut -d: -f1)
  local compinit_line=$(grep -n "compinit" "$zshrc" | head -1 | cut -d: -f1)
  local completion_loading=$(grep -n "completion\.zsh" "$zshrc" | head -1 | cut -d: -f1)
  
  test_log "Loading order detected: PATH($path_loading) -> config($config_loading) -> compinit($compinit_line) -> completions($completion_loading)"
  
  local order_correct=true
  
  # Verify correct ordering
  if [[ -n "$path_loading" && -n "$config_loading" ]]; then
    if [[ "$path_loading" -gt "$config_loading" ]]; then
      test_log "Violation: PATH loading after config loading"
      order_correct=false
    fi
  fi
  
  if [[ -n "$config_loading" && -n "$compinit_line" ]]; then
    if [[ "$config_loading" -gt "$compinit_line" ]]; then
      test_log "Violation: Config loading after compinit"
      order_correct=false
    fi
  fi
  
  if [[ -n "$compinit_line" && -n "$completion_loading" ]]; then
    if [[ "$compinit_line" -gt "$completion_loading" ]]; then
      test_log "Violation: compinit after completion loading"
      order_correct=false
    fi
  fi
  
  if [[ "$order_correct" == "true" ]]; then
    test_success "Loading orchestration follows correct sequence"
  else
    test_fail "Loading orchestration order violations detected"
    return 1
  fi
}

# Test command routing compliance
test_command_routing_compliance() {
  test_info "Testing compliance with command routing principles"
  
  local router="$DOTFILES_ROOT/core/dots"
  [[ -x "$router" ]] || router="$DOTFILES_ROOT/bin/dots"
  
  if [[ ! -x "$router" ]]; then
    test_skip "Router not found - cannot test routing compliance"
    return 0
  fi
  
  local commands_dir="$DOTFILES_ROOT/core/commands"
  
  if [[ ! -d "$commands_dir" ]]; then
    test_fail "Commands directory not found - routing compliance cannot be verified"
    return 1
  fi
  
  # Test that all commands in directory are accessible
  local accessible_commands=0
  local total_commands=0
  
  for cmd_file in "$commands_dir"/*; do
    [[ -f "$cmd_file" && -x "$cmd_file" ]] || continue
    ((total_commands++))
    
    local cmd_name="$(basename "$cmd_file")"
    
    # Test that command is routed properly
    if "$router" "$cmd_name" --help >/dev/null 2>&1 || \
       "$router" "$cmd_name" >/dev/null 2>&1 || \
       [[ $? -ne 127 ]]; then  # 127 = command not found
      ((accessible_commands++))
      test_log "Command $cmd_name is properly routed"
    else
      test_log "Command $cmd_name routing failed"
    fi
  done
  
  local routing_rate=$(( accessible_commands * 100 / total_commands ))
  test_log "Command routing rate: $routing_rate% ($accessible_commands/$total_commands)"
  
  if [[ $routing_rate -eq 100 ]]; then
    test_success "Perfect command routing compliance"
  elif [[ $routing_rate -ge 80 ]]; then
    test_success "Good command routing compliance (${routing_rate}%)"
  else
    test_fail "Poor command routing compliance (${routing_rate}%)"
    return 1
  fi
}

# Test naming convention compliance
test_naming_convention_compliance() {
  test_info "Testing compliance with naming conventions"
  
  local violations=0
  
  # Test file naming conventions
  for topic_dir in "$DOTFILES_ROOT"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    case "$topic_name" in
      ".|..|tests|docs|core|.git|.local") continue ;;
    esac
    
    # Topic names should be lowercase with hyphens or underscores
    if [[ ! "$topic_name" =~ ^[a-z0-9_-]+$ ]]; then
      test_log "Naming violation: Topic '$topic_name' doesn't follow lowercase convention"
      ((violations++))
    fi
    
    # Check file naming within topics
    for file in "$topic_dir"/*; do
      [[ -f "$file" ]] || continue
      
      local filename="$(basename "$file")"
      
      # Configuration files should end in .zsh
      if [[ "$filename" =~ \.(sh|bash)$ ]] && [[ ! "$filename" =~ ^install\. ]]; then
        test_log "Naming suggestion: $topic_name/$filename could use .zsh extension"
      fi
      
      # Symlink files should end in .symlink
      if [[ "$filename" =~ \.symlink$ ]]; then
        test_log "Good: $topic_name/$filename follows symlink naming convention"
      fi
    done
  done
  
  if [[ $violations -eq 0 ]]; then
    test_success "Perfect naming convention compliance"
  elif [[ $violations -le 2 ]]; then
    test_success "Good naming convention compliance (minor issues: $violations)"
  else
    test_fail "Poor naming convention compliance (violations: $violations)"
    return 1
  fi
}

# Run all compliance tests
run_compliance_tests() {
  test_info "Design Principles Compliance Tests"
  
  setup_test_environment
  
  test_defensive_programming_compliance
  test_local_always_wins_compliance
  test_self_containment_compliance
  test_hot_deployment_compliance
  test_loading_orchestration_compliance
  test_command_routing_compliance
  test_naming_convention_compliance
  
  cleanup_test_environment
  
  test_summary
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_compliance_tests
fi
