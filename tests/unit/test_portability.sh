#!/usr/bin/env bash
#
# Portability Test Suite - Comprehensive hardcoded path detection
# Tests for complete portability across macOS systems
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source the test framework
source "$SCRIPT_DIR/../test_framework.sh"

#==============================================================================
# HARDCODED PATH DETECTION TESTS
#==============================================================================

test_no_hardcoded_usernames() {
  echo "= Testing for hardcoded usernames in configuration files"
  
  local found_issues=0
  local suspicious_paths=()
  
  # Search for common hardcoded username patterns
  local patterns=(
    "/Users/[^/\$]+"
    "/home/[^/\$]+"
    "moquette"
    "username"
    "yourname"
    "johndoe"
    "user123"
  )
  
  for pattern in "${patterns[@]}"; do
    # Search in all non-git, non-temp files
    local matches=$(grep -r -E "$pattern" "$DOTFILES_ROOT" \
      --exclude-dir=.git \
      --exclude-dir=node_modules \
      --exclude-dir=.tmp \
      --exclude="*.log" \
      --exclude="*test_portability*" \
      2>/dev/null || true)
    
    if [ -n "$matches" ]; then
      echo "   Found potential hardcoded path pattern: $pattern"
      echo "$matches"
      echo ""
      found_issues=$((found_issues + 1))
      suspicious_paths+=("$pattern: $(echo "$matches" | wc -l) matches")
    fi
  done
  
  if [ $found_issues -gt 0 ]; then
    fail "Found $found_issues hardcoded path patterns. See details above."
    for issue in "${suspicious_paths[@]}"; do
      echo "  - $issue"
    done
    return 1
  fi
  
  pass "No hardcoded usernames found"
}

test_mcp_servers_json_portability() {
  echo "= Testing MCP servers.json for hardcoded paths"
  
  local mcp_config="$DOTFILES_ROOT/claude/mcp/servers.json"
  
  if [ ! -f "$mcp_config" ]; then
    skip "MCP servers.json not found"
    return 0
  fi
  
  # Check for hardcoded paths in MCP configuration
  local hardcoded_paths=$(grep -E '"/Users/[^"]*"' "$mcp_config" || true)
  
  if [ -n "$hardcoded_paths" ]; then
    fail "Found hardcoded paths in MCP configuration:"
    echo "$hardcoded_paths"
    echo ""
    echo "Suggestion: Replace with environment variables like:"
    echo '  "/Users/moquette/Code" ’ "$PROJECTS" or "$HOME/Code"'
    return 1
  fi
  
  # Check for proper use of environment variables
  local has_env_vars=$(grep -E '\$[A-Z_]+|"\$\{[A-Z_]+\}"' "$mcp_config" || echo "none")
  
  pass "MCP servers.json uses portable paths"
  
  if [ "$has_env_vars" = "none" ]; then
    echo "=¡ Suggestion: Consider using environment variables for paths in MCP config"
  fi
}

test_gitconfig_portability() {
  echo "= Testing Git configuration for hardcoded paths"
  
  local gitconfig="$DOTFILES_ROOT/git/gitconfig.symlink"
  
  if [ ! -f "$gitconfig" ]; then
    skip "Git configuration not found"
    return 0
  fi
  
  # Check for hardcoded paths in git configuration
  local issues=()
  
  # Check for hardcoded homebrew paths
  local homebrew_paths=$(grep -E '/(opt/homebrew|usr/local)/bin/[^"]*' "$gitconfig" || true)
  if [ -n "$homebrew_paths" ]; then
    issues+=("Hardcoded Homebrew paths found")
    echo "   Hardcoded Homebrew paths in gitconfig:"
    echo "$homebrew_paths"
  fi
  
  # Check for proper use of environment variables
  local env_usage=$(grep -E '\$[A-Z_]+' "$gitconfig" || true)
  if [ -n "$env_usage" ]; then
    echo " Good: Found environment variable usage:"
    echo "$env_usage"
  fi
  
  if [ ${#issues[@]} -gt 0 ]; then
    fail "Git configuration has portability issues:"
    for issue in "${issues[@]}"; do
      echo "  - $issue"
    done
    return 1
  fi
  
  pass "Git configuration is portable"
}

test_shell_scripts_portability() {
  echo "= Testing shell scripts for hardcoded paths"
  
  local issues=()
  local script_issues=()
  
  # Find all shell scripts
  local shell_scripts=(
    $(find "$DOTFILES_ROOT" -name "*.sh" -type f -not -path "*/.git/*" -not -path "*/test_portability.sh")
    $(find "$DOTFILES_ROOT" -name "*.zsh" -type f -not -path "*/.git/*")
    $(find "$DOTFILES_ROOT/bin" -type f -executable 2>/dev/null || true)
    $(find "$DOTFILES_ROOT/core/commands" -type f 2>/dev/null || true)
  )
  
  for script in "${shell_scripts[@]}"; do
    if [ ! -f "$script" ]; then continue; fi
    
    local script_name=$(basename "$script")
    local script_issues_found=()
    
    # Check for hardcoded user paths
    local user_paths=$(grep -E '/(Users|home)/[^$/"]*[^/]' "$script" | grep -v '\$\|#{' || true)
    if [ -n "$user_paths" ]; then
      script_issues_found+=("Hardcoded user paths")
    fi
    
    # Check for hardcoded absolute paths that should use variables
    local abs_paths=$(grep -E '^[^#]*["\s]/[a-zA-Z]' "$script" | grep -v -E '(usr/local|opt/homebrew|bin/bash|usr/bin|etc/)' | grep -v '\$HOME\|\$ZSH\|\$DOTFILES' || true)
    if [ -n "$abs_paths" ]; then
      script_issues_found+=("Suspicious absolute paths")
    fi
    
    if [ ${#script_issues_found[@]} -gt 0 ]; then
      script_issues+=("$script_name: ${script_issues_found[*]}")
    fi
  done
  
  if [ ${#script_issues[@]} -gt 0 ]; then
    fail "Found portability issues in shell scripts:"
    for issue in "${script_issues[@]}"; do
      echo "  - $issue"
    done
    return 1
  fi
  
  pass "Shell scripts are portable"
}

test_symlink_targets_portability() {
  echo "= Testing symlink targets for portability"
  
  local issues=()
  
  # Find all .symlink files
  local symlink_files=$(find "$DOTFILES_ROOT" -name "*.symlink" -type f)
  
  for file in $symlink_files; do
    local file_name=$(basename "$file")
    
    # Check for hardcoded paths in symlink target files
    local hardcoded=$(grep -E '/(Users|home)/[^$/"]*[^/]' "$file" 2>/dev/null | grep -v '\$HOME\|\$ZSH\|\$DOTFILES\|\$USER' || true)
    
    if [ -n "$hardcoded" ]; then
      issues+=("$file_name has hardcoded paths")
    fi
  done
  
  if [ ${#issues[@]} -gt 0 ]; then
    fail "Found hardcoded paths in symlink target files:"
    for issue in "${issues[@]}"; do
      echo "  - $issue"
    done
    return 1
  fi
  
  pass "Symlink target files are portable"
}

test_environment_variable_usage() {
  echo "= Testing proper environment variable usage"
  
  local good_patterns=()
  local suggestions=()
  
  # Check for proper use of standard environment variables
  local env_vars=("HOME" "USER" "ZSH" "DOTFILES" "PROJECTS")
  
  for var in "${env_vars[@]}"; do
    local usage=$(grep -r "\$$var\|\${$var}" "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" 2>/dev/null | wc -l)
    if [ "$usage" -gt 0 ]; then
      good_patterns+=("$var: $usage usages")
    fi
  done
  
  # Check for paths that should use environment variables
  local should_use_env=$(grep -r "~/Code\|/Users/.*/Code\|~/Projects" "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" 2>/dev/null || true)
  
  if [ -n "$should_use_env" ]; then
    suggestions+=("Found paths that could use \$PROJECTS environment variable")
  fi
  
  pass "Environment variable analysis complete"
  
  if [ ${#good_patterns[@]} -gt 0 ]; then
    echo " Good practices found:"
    for pattern in "${good_patterns[@]}"; do
      echo "  - $pattern"
    done
  fi
  
  if [ ${#suggestions[@]} -gt 0 ]; then
    echo "=¡ Suggestions for improvement:"
    for suggestion in "${suggestions[@]}"; do
      echo "  - $suggestion"
    done
  fi
}

#==============================================================================
# CROSS-PLATFORM COMPATIBILITY TESTS
#==============================================================================

test_macos_specific_commands() {
  echo "= Testing for properly guarded macOS-specific commands"
  
  local macos_commands=("defaults" "osascript" "launchctl" "dscl" "scutil")
  local issues=()
  
  for cmd in "${macos_commands[@]}"; do
    # Look for unguarded usage of macOS commands
    local unguarded=$(grep -r "$cmd" "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" 2>/dev/null | grep -v 'Darwin\|uname.*s' || true)
    
    if [ -n "$unguarded" ]; then
      issues+=("Unguarded $cmd command usage")
    fi
  done
  
  if [ ${#issues[@]} -gt 0 ]; then
    echo "   Found potentially unguarded macOS commands:"
    for issue in "${issues[@]}"; do
      echo "  - $issue"
    done
    echo "Suggestion: Guard with [[ \$(uname -s) == \"Darwin\" ]] checks"
  fi
  
  pass "macOS command usage analysis complete"
}

test_homebrew_path_flexibility() {
  echo "= Testing Homebrew path flexibility for Intel/Apple Silicon"
  
  local homebrew_files=$(grep -r "homebrew\|/opt/homebrew\|/usr/local" "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" -l 2>/dev/null || true)
  local issues=()
  local good_practices=()
  
  for file in $homebrew_files; do
    local file_name=$(basename "$file")
    
    # Check for hardcoded homebrew paths without alternatives
    local has_both_paths=$(grep -E '(opt/homebrew|usr/local)' "$file" | wc -l)
    local has_brew_command=$(grep 'brew ' "$file" || true)
    local has_conditional=$(grep -E '(uname|Darwin|\[\[.*-x.*homebrew)' "$file" || true)
    
    if [ "$has_both_paths" -eq 1 ] && [ -z "$has_conditional" ] && [ -z "$has_brew_command" ]; then
      issues+=("$file_name: Hardcoded single Homebrew path without fallback")
    elif [ "$has_both_paths" -gt 1 ] || [ -n "$has_conditional" ]; then
      good_practices+=("$file_name: Handles multiple Homebrew locations")
    fi
  done
  
  if [ ${#issues[@]} -gt 0 ]; then
    fail "Found Homebrew portability issues:"
    for issue in "${issues[@]}"; do
      echo "  - $issue"
    done
    return 1
  fi
  
  pass "Homebrew paths are flexible"
  
  if [ ${#good_practices[@]} -gt 0 ]; then
    echo " Good practices found:"
    for practice in "${good_practices[@]}"; do
      echo "  - $practice"
    done
  fi
}

#==============================================================================
# INTEGRATION PORTABILITY TESTS
#==============================================================================

test_bootstrap_portability() {
  echo "= Testing bootstrap script portability"
  
  local bootstrap="$DOTFILES_ROOT/core/commands/bootstrap"
  
  if [ ! -f "$bootstrap" ]; then
    skip "Bootstrap script not found"
    return 0
  fi
  
  local issues=()
  
  # Check for proper environment detection
  local has_uname_check=$(grep 'uname -s' "$bootstrap" || true)
  if [ -z "$has_uname_check" ]; then
    issues+=("No OS detection found")
  fi
  
  # Check for hardcoded paths
  local hardcoded_paths=$(grep -E '/(Users|home)/[^$/"]*[^/]' "$bootstrap" | grep -v '\$HOME' || true)
  if [ -n "$hardcoded_paths" ]; then
    issues+=("Contains hardcoded user paths")
  fi
  
  # Check for proper variable usage
  local uses_dotfiles_root=$(grep 'DOTFILES_ROOT' "$bootstrap" || true)
  if [ -z "$uses_dotfiles_root" ]; then
    issues+=("Doesn't use DOTFILES_ROOT variable")
  fi
  
  if [ ${#issues[@]} -gt 0 ]; then
    fail "Bootstrap script has portability issues:"
    for issue in "${issues[@]}"; do
      echo "  - $issue"
    done
    return 1
  fi
  
  pass "Bootstrap script is portable"
}

test_install_script_portability() {
  echo "= Testing install script portability"
  
  local install="$DOTFILES_ROOT/core/commands/install"
  
  if [ ! -f "$install" ]; then
    skip "Install script not found"
    return 0
  fi
  
  local issues=()
  
  # Check for hardcoded paths
  local hardcoded_paths=$(grep -E '/(Users|home)/[^$/"]*[^/]' "$install" | grep -v '\$HOME' || true)
  if [ -n "$hardcoded_paths" ]; then
    issues+=("Contains hardcoded user paths")
  fi
  
  # Check for proper Homebrew handling
  local homebrew_handling=$(grep -A5 -B5 'brew' "$install" | grep -E '(opt/homebrew|usr/local)' || true)
  if [ -n "$homebrew_handling" ]; then
    echo " Found Homebrew path handling"
  fi
  
  if [ ${#issues[@]} -gt 0 ]; then
    fail "Install script has portability issues:"
    for issue in "${issues[@]}"; do
      echo "  - $issue"
    done
    return 1
  fi
  
  pass "Install script is portable"
}

#==============================================================================
# COMPREHENSIVE SIMULATION TESTS
#==============================================================================

test_simulate_different_user() {
  echo "= Testing simulation with different username"
  
  # Create a temporary directory to simulate different user
  local temp_home=$(mktemp -d)
  local temp_user="testuser123"
  
  # Override HOME for testing
  local original_home="$HOME"
  export HOME="$temp_home"
  
  # Create basic directory structure
  mkdir -p "$temp_home/.dotfiles"
  mkdir -p "$temp_home/Code"
  
  local issues=()
  
  # Test if dotfiles would work with different username
  # This is a dry-run test that checks for obvious problems
  
  # Check if any files reference the original username
  local username_refs=$(grep -r "$(whoami)" "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" 2>/dev/null || true)
  
  if [ -n "$username_refs" ]; then
    issues+=("Found references to current username: $(whoami)")
  fi
  
  # Check if HOME variable usage would work
  local home_usage_count=$(grep -r '\$HOME' "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" 2>/dev/null | wc -l)
  
  if [ "$home_usage_count" -gt 0 ]; then
    echo " Found $home_usage_count uses of \$HOME variable"
  fi
  
  # Restore original HOME
  export HOME="$original_home"
  rm -rf "$temp_home"
  
  if [ ${#issues[@]} -gt 0 ]; then
    fail "Found issues with different username simulation:"
    for issue in "${issues[@]}"; do
      echo "  - $issue"
    done
    return 1
  fi
  
  pass "Different username simulation successful"
}

test_simulate_different_directories() {
  echo "= Testing simulation with different directory structures"
  
  local issues=()
  
  # Check for assumptions about directory names
  local code_assumptions=$(grep -r "Code/" "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" 2>/dev/null || true)
  local projects_assumptions=$(grep -r "Projects/" "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" 2>/dev/null || true)
  
  if [ -n "$code_assumptions" ]; then
    echo "   Found assumptions about 'Code' directory:"
    echo "$code_assumptions"
    echo "Suggestion: Use \$PROJECTS environment variable"
  fi
  
  if [ -n "$projects_assumptions" ]; then
    echo "   Found assumptions about 'Projects' directory:"
    echo "$projects_assumptions"
    echo "Suggestion: Use \$PROJECTS environment variable"
  fi
  
  # Check for flexible path handling
  local env_path_usage=$(grep -r '\$PROJECTS\|\${PROJECTS}' "$DOTFILES_ROOT" --exclude-dir=.git --exclude="*test_portability*" 2>/dev/null | wc -l)
  
  if [ "$env_path_usage" -gt 0 ]; then
    echo " Found $env_path_usage uses of \$PROJECTS variable"
  fi
  
  pass "Directory structure simulation complete"
}

#==============================================================================
# MAIN TEST RUNNER
#==============================================================================

main() {
  echo "=€ Starting Comprehensive Dotfiles Portability Test Suite"
  echo "=========================================================="
  echo ""
  
  # Track test results
  local total_tests=0
  local passed_tests=0
  local failed_tests=0
  local skipped_tests=0
  
  # Define all tests to run
  local tests=(
    "test_no_hardcoded_usernames"
    "test_mcp_servers_json_portability"
    "test_gitconfig_portability"
    "test_shell_scripts_portability"
    "test_symlink_targets_portability"
    "test_environment_variable_usage"
    "test_macos_specific_commands"
    "test_homebrew_path_flexibility"
    "test_bootstrap_portability"
    "test_install_script_portability"
    "test_simulate_different_user"
    "test_simulate_different_directories"
  )
  
  # Run all tests
  for test_func in "${tests[@]}"; do
    echo ""
    total_tests=$((total_tests + 1))
    
    if $test_func; then
      passed_tests=$((passed_tests + 1))
    else
      failed_tests=$((failed_tests + 1))
    fi
  done
  
  echo ""
  echo "=========================================================="
  echo "=Ê PORTABILITY TEST RESULTS"
  echo "=========================================================="
  echo "Total tests:  $total_tests"
  echo "Passed:       $passed_tests"
  echo "Failed:       $failed_tests"
  echo "Success rate: $(echo "scale=1; $passed_tests * 100 / $total_tests" | bc -l 2>/dev/null || echo "N/A")"
  echo ""
  
  if [ $failed_tests -gt 0 ]; then
    echo "L PORTABILITY ISSUES DETECTED"
    echo "The dotfiles have portability issues that need to be addressed."
    echo "See the detailed test output above for specific problems and suggestions."
    return 1
  else
    echo " EXCELLENT PORTABILITY"
    echo "The dotfiles appear to be highly portable across different macOS systems."
  fi
  
  echo ""
  echo "=' RECOMMENDED IMPROVEMENTS:"
  echo ""
  echo "1. Use environment variables:"
  echo "   - \$HOME instead of /Users/username"
  echo "   - \$PROJECTS instead of ~/Code or hardcoded project paths"
  echo "   - \$ZSH instead of hardcoded dotfiles path"
  echo ""
  echo "2. Guard platform-specific commands:"
  echo "   - Wrap macOS commands with: [[ \$(uname -s) == \"Darwin\" ]]"
  echo ""
  echo "3. Handle multiple Homebrew locations:"
  echo "   - Check both /opt/homebrew and /usr/local"
  echo "   - Use 'brew --prefix' when possible"
  echo ""
  echo "4. Use relative paths in configuration files"
  echo "5. Test with different usernames and directory structures"
  echo ""
}

# Run the test suite if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi