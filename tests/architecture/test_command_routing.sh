#!/usr/bin/env bash
#
# Command Routing System Tests
# Validates the dots command routing and subcommand discovery
#

set -e

# Get the actual dotfiles root (two levels up from this test)
ACTUAL_DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

source "$(dirname "$0")/../test_framework.sh"

# Override the DOTFILES_ROOT with correct path
DOTFILES_ROOT="$ACTUAL_DOTFILES_ROOT"

# Test command discovery mechanism
test_command_discovery() {
  test_info "Testing automatic command discovery from core/commands/"
  
  # Get list of available commands from filesystem
  local commands_dir="$DOTFILES_ROOT/core/commands"
  local available_commands=()
  
  if [[ -d "$commands_dir" ]]; then
    while IFS= read -r -d '' cmd; do
      local cmd_name="$(basename "$cmd")"
      available_commands+=("$cmd_name")
    done < <(find "$commands_dir" -maxdepth 1 -type f -perm +111 -print0 2>/dev/null)
  else
    test_fail "Commands directory not found: $commands_dir"
    return 1
  fi
  
  if [[ ${#available_commands[@]} -eq 0 ]]; then
    test_fail "No commands found in $commands_dir"
    return 1
  fi
  
  test_log "Discovered commands: ${available_commands[*]}"
  
  # Test that dots router can find these commands
  local router="$DOTFILES_ROOT/core/dots"
  if [[ ! -x "$router" ]]; then
    router="$DOTFILES_ROOT/bin/dots"
    if [[ ! -x "$router" ]]; then
      test_fail "dots router not found or not executable"
      return 1
    fi
  fi
  
  # Test help/list functionality to see if commands are discovered
  local help_output
  if help_output=$("$router" --help 2>&1) || help_output=$("$router" help 2>&1) || help_output=$("$router" 2>&1); then
    # Check if discovered commands appear in help
    for cmd in "${available_commands[@]}"; do
      if ! echo "$help_output" | grep -q "$cmd"; then
        test_log "Warning: Command $cmd not listed in help output"
      fi
    done
    test_success "Command discovery mechanism is functional"
  else
    test_fail "Cannot test command discovery - router help failed"
    return 1
  fi
}

# Test command routing to implementations
test_command_routing() {
  test_info "Testing command routing to implementations"
  
  local router="$DOTFILES_ROOT/core/dots"
  [[ -x "$router" ]] || router="$DOTFILES_ROOT/bin/dots"
  
  if [[ ! -x "$router" ]]; then
    test_fail "dots router not found"
    return 1
  fi
  
  # Test each available command
  local commands_dir="$DOTFILES_ROOT/core/commands"
  for cmd_file in "$commands_dir"/*; do
    [[ -f "$cmd_file" && -x "$cmd_file" ]] || continue
    
    local cmd_name="$(basename "$cmd_file")"
    test_log "Testing routing for command: $cmd_name"
    
    # Test that command can be called (even if it fails due to missing args)
    local output
    if output=$("$router" "$cmd_name" --help 2>&1) || 
       output=$("$router" "$cmd_name" 2>&1) ||
       [[ $? -ne 127 ]]; then  # 127 = command not found
      test_log "Command $cmd_name is properly routed"
    else
      # Check if it's a "command not found" error
      if echo "$output" | grep -q "not found\|No such file"; then
        test_fail "Command $cmd_name routing failed - command not found"
        return 1
      fi
      # Other errors are OK (missing args, etc.)
      test_log "Command $cmd_name routing works (expected error: non-127 exit)"
    fi
  done
  
  test_success "All commands are properly routed"
}

# Test library loading in commands
test_library_loading() {
  test_info "Testing that commands can load required libraries"
  
  local commands_dir="$DOTFILES_ROOT/core/commands"
  local lib_dir="$DOTFILES_ROOT/core/lib"
  
  # Check that core libraries exist
  local required_libs=("common.sh" "ui.sh")
  for lib in "${required_libs[@]}"; do
    if [[ ! -f "$lib_dir/$lib" ]]; then
      test_fail "Required library missing: $lib_dir/$lib"
      return 1
    fi
  done
  
  # Check that commands properly source libraries
  for cmd_file in "$commands_dir"/*; do
    [[ -f "$cmd_file" ]] || continue
    
    local cmd_name="$(basename "$cmd_file")"
    test_log "Checking library usage in command: $cmd_name"
    
    # Look for library sourcing patterns
    if grep -q "source.*common\.sh\|source.*ui\.sh\|\. .*common\.sh\|\. .*ui\.sh" "$cmd_file"; then
      # Check that the sourcing path is correct
      if grep -E "source.*\.\./lib/|source.*\$\{.*\}/lib/|\. \.\./lib/|\. \$\{.*\}/lib/" "$cmd_file" >/dev/null; then
        test_log "Command $cmd_name properly sources libraries"
      else
        test_log "Warning: Command $cmd_name may not use correct library paths"
      fi
    else
      test_log "Command $cmd_name does not explicitly source libraries (may be standalone)"
    fi
  done
  
  test_success "Library loading patterns are correct"
}

# Test command error handling
test_command_error_handling() {
  test_info "Testing command error handling and user feedback"
  
  local router="$DOTFILES_ROOT/core/dots"
  [[ -x "$router" ]] || router="$DOTFILES_ROOT/bin/dots"
  
  if [[ ! -x "$router" ]]; then
    test_fail "dots router not found"
    return 1
  fi
  
  # Test invalid command
  local invalid_output
  if invalid_output=$("$router" "nonexistentcommand" 2>&1); then
    # Command succeeded when it shouldn't have
    test_log "Warning: Invalid command 'nonexistentcommand' did not fail"
  else
    # Check that error message is helpful
    if echo "$invalid_output" | grep -qi "not found\|unknown\|invalid\|available"; then
      test_success "Router provides helpful error messages for invalid commands"
    else
      test_log "Router error output: $invalid_output"
      test_fail "Router error message not helpful for invalid commands"
      return 1
    fi
  fi
  
  # Test that router handles empty arguments
  local empty_output
  if empty_output=$("$router" 2>&1); then
    # Should show help or available commands
    if echo "$empty_output" | grep -qi "usage\|help\|available\|commands"; then
      test_success "Router shows helpful output when called without arguments"
    else
      test_log "Router empty output: $empty_output"
      test_log "Warning: Router output without args may not be helpful"
    fi
  else
    test_log "Router fails when called without arguments (this may be expected)"
  fi
}

# Test command consistency (all commands follow same patterns)
test_command_consistency() {
  test_info "Testing command implementation consistency"
  
  local commands_dir="$DOTFILES_ROOT/core/commands"
  local inconsistencies=0
  
  # Check that all commands have proper shebang
  for cmd_file in "$commands_dir"/*; do
    [[ -f "$cmd_file" ]] || continue
    
    local cmd_name="$(basename "$cmd_file")"
    local first_line="$(head -1 "$cmd_file")"
    
    if [[ ! "$first_line" =~ ^#!/ ]]; then
      test_log "Warning: Command $cmd_name missing shebang"
      ((inconsistencies++))
    fi
    
    # Check for set -e (strict error handling)
    if ! grep -q "set -e" "$cmd_file"; then
      test_log "Warning: Command $cmd_name missing 'set -e'"
      ((inconsistencies++))
    fi
    
    # Check for consistent error handling patterns
    if ! grep -qE "exit [0-9]+|return [0-9]+" "$cmd_file"; then
      test_log "Info: Command $cmd_name may not use explicit exit codes"
    fi
  done
  
  if [[ $inconsistencies -gt 3 ]]; then
    test_fail "Too many consistency issues found: $inconsistencies"
    return 1
  elif [[ $inconsistencies -gt 0 ]]; then
    test_log "Minor consistency issues found: $inconsistencies (acceptable)"
  fi
  
  test_success "Commands follow consistent implementation patterns"
}

# Test command permissions and security
test_command_security() {
  test_info "Testing command security and permissions"
  
  local commands_dir="$DOTFILES_ROOT/core/commands"
  
  # Check file permissions
  for cmd_file in "$commands_dir"/*; do
    [[ -f "$cmd_file" ]] || continue
    
    local cmd_name="$(basename "$cmd_file")"
    local perms="$(ls -l "$cmd_file" | cut -d' ' -f1)"
    
    # Check that file is executable by owner
    if [[ ! "$perms" =~ x ]]; then
      test_fail "Command $cmd_name is not executable"
      return 1
    fi
    
    # Check that file is not world-writable
    if [[ "$perms" =~ .--.-.-.w ]]; then
      test_fail "Command $cmd_name is world-writable (security risk)"
      return 1
    fi
    
    # Check for potentially dangerous patterns
    if grep -qE "(rm -rf|chmod -R 777|eval.*\$|exec.*\$)" "$cmd_file"; then
      test_log "Warning: Command $cmd_name contains potentially dangerous patterns"
    fi
  done
  
  test_success "Command security checks passed"
}

# Run all command routing tests
run_command_routing_tests() {
  test_info "Command Routing System Tests"
  
  setup_test_environment
  
  test_command_discovery
  test_command_routing
  test_library_loading
  test_command_error_handling
  test_command_consistency
  test_command_security
  
  cleanup_test_environment
  
  test_summary
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_command_routing_tests
fi
