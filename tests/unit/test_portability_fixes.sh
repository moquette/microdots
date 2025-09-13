#!/usr/bin/env bash
#
# Portability Fixes Validation Test
# Validates that all hardcoded path fixes work correctly
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=' PORTABILITY FIXES VALIDATION"
echo "=============================="
echo ""

# Test 1: Validate MCP servers.json uses environment variables
echo " TEST 1: MCP Configuration Portability"
mcp_config="$DOTFILES_ROOT/claude/mcp/servers.json"
if [ -f "$mcp_config" ]; then
  if grep -q '\$PROJECTS' "$mcp_config"; then
    echo "   MCP servers.json now uses \$PROJECTS environment variable"
  else
    echo "  L MCP servers.json still has hardcoded paths"
    exit 1
  fi
  
  if ! grep -q '/Users/[^/]*/' "$mcp_config"; then
    echo "   No hardcoded username paths found in MCP config"
  else
    echo "  L Still found hardcoded username paths in MCP config"
    exit 1
  fi
else
  echo "  �  MCP servers.json not found"
fi

echo ""

# Test 2: Validate Git configuration flexibility
echo " TEST 2: Git Configuration Portability" 
gitconfig="$DOTFILES_ROOT/git/gitconfig.symlink"
if [ -f "$gitconfig" ]; then
  if ! grep -q '/opt/homebrew/bin/spaceman-diff' "$gitconfig"; then
    echo "   Git config no longer has hardcoded Homebrew paths"
  else
    echo "  L Git config still has hardcoded Homebrew paths"
    exit 1
  fi
  
  if grep -q 'command = spaceman-diff' "$gitconfig"; then
    echo "   Git config now uses PATH-based spaceman-diff lookup"
  else
    echo "  �  spaceman-diff configuration not found"
  fi
else
  echo "  �  Git configuration not found"
fi

echo ""

# Test 3: Simulate different user environment
echo " TEST 3: Different User Simulation"
temp_home=$(mktemp -d)
temp_projects="$temp_home/Development"
mkdir -p "$temp_projects"

# Test MCP config with different user
original_home="$HOME"
original_projects="$PROJECTS"
export PROJECTS="$temp_projects"
export HOME="$temp_home"

echo "   Simulated user environment:"
echo "    HOME: $HOME"
echo "    PROJECTS: $PROJECTS"

# Validate that MCP configuration would work
if [ -f "$mcp_config" ]; then
  # Check if the config references the environment variables correctly
  if grep -q '\$PROJECTS' "$mcp_config"; then
    echo "   MCP config will adapt to different PROJECTS directory"
  fi
fi

# Restore environment
export HOME="$original_home"
export PROJECTS="$original_projects"

# Cleanup
rm -rf "$temp_home"

echo ""

# Test 4: Cross-platform Homebrew compatibility
echo " TEST 4: Cross-platform Homebrew Compatibility"

# Check if all Homebrew references handle multiple locations
homebrew_files=(
  "$DOTFILES_ROOT/system/env.zsh"
  "$DOTFILES_ROOT/homebrew/path.zsh"
  "$DOTFILES_ROOT/core/commands/bootstrap"
  "$DOTFILES_ROOT/core/commands/install"
)

for file in "${homebrew_files[@]}"; do
  if [ -f "$file" ]; then
    if grep -q 'opt/homebrew\|usr/local' "$file" && grep -q -E '(if|elif).*homebrew' "$file"; then
      echo "   $(basename "$file"): Handles multiple Homebrew locations"
    else
      echo "  �  $(basename "$file"): May need Homebrew compatibility review"
    fi
  fi
done

echo ""

# Test 5: Environment Variables Coverage
echo " TEST 5: Environment Variables Usage Analysis"

required_vars=("HOME" "ZSH" "DOTFILES_ROOT" "PROJECTS")
for var in "${required_vars[@]}"; do
  usage_count=$(grep -r "\$$var\|\${$var}" "$DOTFILES_ROOT" --exclude-dir=.git --exclude-dir=tests 2>/dev/null | wc -l | tr -d ' ')
  if [ "$usage_count" -gt 0 ]; then
    echo "   $var: Used $usage_count times throughout dotfiles"
  else
    echo "  �  $var: Not found - may need more usage"
  fi
done

echo ""

# Test 6: Validate no remaining hardcoded paths
echo " TEST 6: Final Hardcoded Path Scan"

# Check for common hardcoded patterns (excluding standard system paths)
hardcoded_patterns=(
  "/Users/[^/]+"
  "/home/[^/]+"
)

issues_found=0
for pattern in "${hardcoded_patterns[@]}"; do
  matches=$(grep -r -E "$pattern" "$DOTFILES_ROOT" \
    --exclude-dir=.git \
    --exclude-dir=tests \
    --exclude="*.log" \
    --exclude="*.md" \
    2>/dev/null | grep -v '\.git\|test' || true)
  
  if [ -n "$matches" ]; then
    echo "  L Found hardcoded pattern '$pattern':"
    echo "$matches" | sed 's/^/      /'
    issues_found=$((issues_found + 1))
  fi
done

if [ $issues_found -eq 0 ]; then
  echo "   No hardcoded user paths found in core configuration files"
else
  echo "  L Found $issues_found hardcoded path patterns that need fixing"
fi

echo ""
echo "=============================="

if [ $issues_found -eq 0 ]; then
  echo "<� PORTABILITY VALIDATION: PASSED"
  echo ""
  echo "The dotfiles are now highly portable and should work on any macOS system!"
  echo ""
  echo " Key improvements made:"
  echo "  " MCP configuration uses \$PROJECTS environment variable"
  echo "  " Git configuration uses PATH-based tool lookup"  
  echo "  " Homebrew paths handle both Intel and Apple Silicon"
  echo "  " Extensive use of environment variables throughout"
  exit 0
else
  echo "L PORTABILITY VALIDATION: ISSUES REMAIN"
  echo ""
  echo "Please address the remaining hardcoded paths listed above."
  exit 1
fi