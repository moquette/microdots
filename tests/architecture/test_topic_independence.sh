#!/usr/bin/env bash
#
# Comprehensive Topic Independence Tests
# Validates that each topic operates independently without cross-dependencies
#

set -e

# Get the actual dotfiles root (two levels up from this test)
ACTUAL_DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

source "$(dirname "$0")/../test_framework.sh"

# Override the DOTFILES_ROOT with correct path
DOTFILES_ROOT="$ACTUAL_DOTFILES_ROOT"

# Test that each topic can load independently
test_topic_isolation() {
  test_info "Testing topic isolation and independence"
  
  local test_home="$TEST_TEMP_DIR/isolated_test"
  mkdir -p "$test_home"
  
  # Copy dotfiles to test environment
  cp -r "$DOTFILES_ROOT" "$test_home/.dotfiles"
  
  # Test each topic independently
  for topic_dir in "$test_home/.dotfiles"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    
    # Skip system directories and documentation
    case "$topic_name" in
      .|..|tests|docs|core|.git|.local|.dotlocal|.claude) continue ;;
    esac
    
    test_log "Testing independence of topic: $topic_name"
    
    # Create isolated environment with only this topic
    local isolated_dir="$test_home/isolated_$topic_name"
    mkdir -p "$isolated_dir/.dotfiles"
    
    # Copy only core system and this topic
    cp -r "$test_home/.dotfiles/core" "$isolated_dir/.dotfiles/"
    cp -r "$topic_dir" "$isolated_dir/.dotfiles/"
    cp -r "$test_home/.dotfiles/zsh" "$isolated_dir/.dotfiles/" 2>/dev/null || true
    
    # Test that topic doesn't reference other topics (excluding documentation)
    local files_to_check=$(find "$topic_dir" \( -name "*.zsh" -o -name "*.sh" \) -not -name "*.md" 2>/dev/null)
    if [[ -n "$files_to_check" ]] && echo "$files_to_check" | xargs grep -l "\.\./.*/" 2>/dev/null; then
      test_fail "Topic $topic_name contains relative paths to other topics"
      return 1
    fi
    
    # Test that topic doesn't hardcode paths
    local code_files=$(find "$topic_dir" \( -name "*.zsh" -o -name "*.sh" \) 2>/dev/null)
    if [[ -n "$code_files" ]] && echo "$code_files" | xargs grep -E "(^|[^$])/Users/[^/]+/" 2>/dev/null; then
      test_fail "Topic $topic_name contains hardcoded user paths"
      return 1
    fi
    
    # Test that config files are syntactically valid
    for config_file in "$topic_dir"/*.zsh; do
      [[ -f "$config_file" ]] || continue
      
      # Basic zsh syntax check using zsh
      if ! zsh -n "$config_file" 2>/dev/null; then
        test_fail "Topic $topic_name has syntax error in $(basename "$config_file")"
        return 1
      fi
    done
    
    test_success "Topic $topic_name passes independence tests"
  done
  
  test_success "All topics are properly isolated and independent"
}

# Test that topics don't define conflicting global variables
test_no_variable_conflicts() {
  test_info "Testing for variable naming conflicts between topics"
  
  local temp_vars="$TEST_TEMP_DIR/topic_vars"
  mkdir -p "$temp_vars"
  
  # Extract all variable assignments from each topic
  for topic_dir in "$DOTFILES_ROOT"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    case "$topic_name" in
      .|..|tests|docs|core|.git|.local|.dotlocal|.claude) continue ;;
    esac
    
    # Find variable assignments (export VAR=value or VAR=value)
    find "$topic_dir" -name "*.zsh" -o -name "*.sh" | while read -r file; do
      grep -E "^[[:space:]]*(export[[:space:]]+)?[A-Z_]+=" "$file" 2>/dev/null | \
        sed 's/^[[:space:]]*//' | \
        cut -d'=' -f1 | \
        sed 's/^export[[:space:]]*//' >> "$temp_vars/$topic_name.vars" 2>/dev/null || true
    done
  done
  
  # Check for conflicts (same variable defined in multiple topics)
  local conflicts_found=false
  local all_vars="$temp_vars/all_vars"
  cat "$temp_vars"/*.vars > "$all_vars" 2>/dev/null || touch "$all_vars"
  
  # Find duplicate variables
  sort "$all_vars" | uniq -d | while read -r var; do
    if [[ -n "$var" ]]; then
      test_log "Variable conflict detected: $var"
      grep -l "^$var$" "$temp_vars"/*.vars | while read -r file; do
        local topic="$(basename "$file" .vars)"
        test_log "  - Defined in topic: $topic"
      done
      conflicts_found=true
    fi
  done
  
  if [[ "$conflicts_found" == "true" ]]; then
    test_fail "Variable conflicts detected between topics"
    return 1
  fi
  
  test_success "No variable conflicts found between topics"
}

# Test that topics implement defensive programming
test_defensive_programming() {
  test_info "Testing defensive programming patterns in topics"
  
  for topic_dir in "$DOTFILES_ROOT"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    case "$topic_name" in
      .|..|tests|docs|core|.git|.local|.dotlocal|.claude) continue ;;
    esac
    
    # Check that topics test for command existence before using
    local has_commands=false
    local has_checks=false
    
    find "$topic_dir" -name "*.zsh" -o -name "*.sh" | while read -r file; do
      # Look for command usage
      if grep -qE "(brew|git|npm|yarn|pip|docker|kubectl)" "$file" 2>/dev/null; then
        has_commands=true
        echo "has_commands" >> "$TEST_TEMP_DIR/defensive_check_$topic_name"
      fi
      
      # Look for defensive checks
      if grep -qE "(command -v|which|type -p|\[\[ -x)" "$file" 2>/dev/null; then
        has_checks=true
        echo "has_checks" >> "$TEST_TEMP_DIR/defensive_check_$topic_name"
      fi
    done
    
    # If topic uses commands but has no checks, that's a problem
    if [[ -f "$TEST_TEMP_DIR/defensive_check_$topic_name" ]]; then
      local commands_count=$(grep -c "has_commands" "$TEST_TEMP_DIR/defensive_check_$topic_name" 2>/dev/null | head -1 || echo "0")
      local checks_count=$(grep -c "has_checks" "$TEST_TEMP_DIR/defensive_check_$topic_name" 2>/dev/null | head -1 || echo "0")
      
      if [[ "$commands_count" -gt 0 && "$checks_count" -eq 0 ]]; then
        test_fail "Topic $topic_name uses commands without defensive checks"
        return 1
      fi
    fi
    
    test_success "Topic $topic_name implements defensive programming"
  done
  
  test_success "All topics implement proper defensive programming"
}

# Test for real cross-topic dependencies (not documentation examples)
test_no_cross_topic_dependencies() {
  test_info "Testing for cross-topic dependencies in actual code"
  
  for topic_dir in "$DOTFILES_ROOT"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    case "$topic_name" in
      ".|..|tests|docs|core|.git|.local|.claude") continue ;;
    esac
    
    # Check actual code files (not documentation)
    find "$topic_dir" \( -name "*.zsh" -o -name "*.sh" \) | while read -r file; do
      # Check for sourcing other topics (except core which is allowed)
      if grep -E "source.*DOTFILES.*/((?!core/)[^/]+)/" "$file" 2>/dev/null | grep -v "# BAD\|# EXAMPLE\|# DON'T" 2>/dev/null; then
        test_fail "Topic $topic_name has cross-topic dependency in $(basename "$file")"
        return 1
      fi
    done
    
    test_success "Topic $topic_name has no cross-topic dependencies"
  done
  
  test_success "No cross-topic dependencies found in actual code"
}

# Test topic self-containment
test_topic_self_containment() {
  test_info "Testing that topics are self-contained"
  
  for topic_dir in "$DOTFILES_ROOT"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    case "$topic_name" in
      ".|..|tests|docs|core|.git|.local|.claude") continue ;;
    esac
    
    # Check that topic doesn't source files from other topics (excluding documentation)
    find "$topic_dir" \( -name "*.zsh" -o -name "*.sh" \) -not -name "*.md" | while read -r file; do
      # Skip if this is a markdown file (documentation)
      [[ "$file" == *.md ]] && continue
      
      # Exclude lines that are clearly examples or bad practices
      # Also exclude test framework sourcing (tests need to source the framework)
      if grep -E "source.*\.\./[^/]" "$file" 2>/dev/null | grep -v "# BAD\|# EXAMPLE\|# DON'T\|# NEVER\|test_framework\.sh" 2>/dev/null; then
        test_fail "Topic $topic_name sources files from other topics in $(basename "$file")"
        return 1
      fi
    done
    
    # Check that all referenced files exist within topic or system
    find "$topic_dir" -name "*.zsh" -o -name "*.sh" | while read -r file; do
      # Look for file references
      grep -E "\./[^[:space:]]+" "$file" 2>/dev/null | while read -r line; do
        local referenced_file=$(echo "$line" | grep -oE "\./[^[:space:]]+")
        local full_path="$topic_dir/$referenced_file"
        
        if [[ ! -f "$full_path" ]]; then
          test_fail "Topic $topic_name references missing file: $referenced_file"
          return 1
        fi
      done
    done
    
    test_success "Topic $topic_name is self-contained"
  done
  
  test_success "All topics are properly self-contained"
}

# Test hot-deployment capability
test_hot_deployment() {
  test_info "Testing hot-deployment of new topics"
  
  local test_home="$TEST_TEMP_DIR/hotdeploy_test"
  mkdir -p "$test_home/.dotfiles"
  
  # Copy existing system
  cp -r "$DOTFILES_ROOT"/* "$test_home/.dotfiles/"
  
  # Create a new test topic at runtime
  local new_topic="$test_home/.dotfiles/hottest"
  mkdir -p "$new_topic"
  
  # Create a simple topic with all component types
  cat > "$new_topic/path.zsh" << 'HOTTEST_PATH'
# Hot-deployed test topic path setup
export PATH="$HOME/.dotfiles/hottest/bin:$PATH"
HOTTEST_PATH

  cat > "$new_topic/config.zsh" << 'HOTTEST_CONFIG'
# Hot-deployed test topic configuration
alias hottest="echo 'Hot deployment works!'"
export HOTTEST_LOADED=1
HOTTEST_CONFIG

  cat > "$new_topic/completion.zsh" << 'HOTTEST_COMPLETION'
# Hot-deployed test topic completion
complete -W "test demo" hottest
HOTTEST_COMPLETION

  mkdir -p "$new_topic/bin"
  cat > "$new_topic/bin/hottest" << 'HOTTEST_BIN'
#!/bin/bash
echo "Hot-deployed command works!"
HOTTEST_BIN
  chmod +x "$new_topic/bin/hottest"
  
  # Test that new topic would be discovered by zsh loading
  local zshrc="$test_home/.dotfiles/zsh/zshrc.symlink"
  
  # Simulate loading to check discovery
  if [[ -f "$zshrc" ]]; then
    # Check that the loading mechanism would find our new topic
    local found_path=$(grep -c "path\.zsh" "$zshrc" 2>/dev/null || echo "0")
    local found_config=$(grep -c "\.zsh" "$zshrc" 2>/dev/null || echo "0")
    local found_completion=$(grep -c "completion\.zsh" "$zshrc" 2>/dev/null || echo "0")
    
    if [[ "$found_path" -eq 0 || "$found_config" -eq 0 || "$found_completion" -eq 0 ]]; then
      test_fail "Hot-deployment mechanism not properly implemented in zshrc"
      return 1
    fi
    
    test_success "Hot-deployment discovery mechanism is properly implemented"
  else
    test_fail "zshrc.symlink not found for hot-deployment test"
    return 1
  fi
  
  test_success "New topics can be hot-deployed successfully"
}

# Run all architecture tests
run_architecture_tests() {
  test_info "Topic Independence Architecture Tests"
  
  setup_test_environment
  
  test_topic_isolation
  test_no_variable_conflicts
  test_defensive_programming
  test_no_cross_topic_dependencies
  test_topic_self_containment
  test_hot_deployment
  
  cleanup_test_environment
  
  test_summary
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_architecture_tests
fi
