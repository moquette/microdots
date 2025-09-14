#!/usr/bin/env bash
#
# Command Substitution Contamination Audit
# Detects potential bugs where functions output to stdout when used in command substitution
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
CRITICAL_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0

header() {
    echo -e "${BLUE}=== $1 ===${NC}"
    echo
}

critical() {
    echo -e "${RED}[CRITICAL] $1${NC}"
    ((CRITICAL_COUNT++))
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    ((WARNING_COUNT++))
}

info_msg() {
    echo -e "${GREEN}[INFO] $1${NC}"
    ((INFO_COUNT++))
}

header "Command Substitution Contamination Audit"

echo "Scanning for potential command substitution contamination bugs..."
echo "These occur when functions output to stdout but are used in \$(function_call) patterns."
echo

# Find all functions that are used in command substitution
header "Phase 1: Finding Command Substitution Usage"

# Find command substitution patterns
echo "Finding all command substitution patterns..."
SUBSTITUTION_PATTERNS=$(find /Users/moquette/.dotfiles -type f \( -name "*.sh" -o -name "bootstrap" -o -name "relink" -o -name "status" -o -name "install" \) -exec grep -l '\$(' {} \; 2>/dev/null || true)

if [[ -n "$SUBSTITUTION_PATTERNS" ]]; then
    echo "Files with command substitution found:"
    echo "$SUBSTITUTION_PATTERNS"
    echo

    # Extract function names used in substitution
    echo "Extracting function names used in substitution..."
    FUNCTIONS_IN_SUBSTITUTION=$(find /Users/moquette/.dotfiles -type f \( -name "*.sh" -o -name "bootstrap" -o -name "relink" -o -name "status" -o -name "install" \) -exec grep -oE '\$\([^)]+\)' {} \; 2>/dev/null | sed 's/\$(\([^)]*\))/\1/' | sort -u)

    echo "Functions/commands used in substitution:"
    echo "$FUNCTIONS_IN_SUBSTITUTION"
    echo
else
    warning "No command substitution patterns found"
fi

header "Phase 2: Analyzing Critical Functions"

# Check specific functions we know are problematic
CRITICAL_FUNCTIONS=(
    "discover_dotlocal_path"
    "resolve_dotlocal_path"
    "get_dotlocal_discovery_method"
    "get_dotlocal_type"
    "get_dotlocal_status"
)

for func in "${CRITICAL_FUNCTIONS[@]}"; do
    echo "Analyzing function: $func"

    # Find where function is defined
    FUNCTION_DEF=$(find /Users/moquette/.dotfiles -type f -name "*.sh" -exec grep -l "^${func}()" {} \; 2>/dev/null || find /Users/moquette/.dotfiles -type f -name "*.sh" -exec grep -l "^function ${func}" {} \; 2>/dev/null || true)

    if [[ -n "$FUNCTION_DEF" ]]; then
        echo "  Defined in: $FUNCTION_DEF"

        # Find where function is used in command substitution
        SUBSTITUTION_USAGE=$(find /Users/moquette/.dotfiles -type f \( -name "*.sh" -o -name "bootstrap" -o -name "relink" -o -name "status" -o -name "install" \) -exec grep -n "\$.*${func}" {} \; 2>/dev/null || true)

        if [[ -n "$SUBSTITUTION_USAGE" ]]; then
            critical "Function '$func' used in command substitution:"
            echo "$SUBSTITUTION_USAGE" | while read -r line; do
                echo "    $line"
            done
            echo

            # Check if function has stdout output that could contaminate
            OUTPUT_PATTERNS=$(grep -A 20 "^${func}()" "$FUNCTION_DEF" 2>/dev/null | grep -E "(echo|info|success|warning|error|progress)" | head -5 || true)
            if [[ -n "$OUTPUT_PATTERNS" ]]; then
                critical "Function '$func' contains potentially contaminating output:"
                echo "$OUTPUT_PATTERNS" | while read -r line; do
                    echo "      $line"
                done
                echo
            fi
        else
            info_msg "Function '$func' not found in command substitution (safe)"
        fi
    else
        warning "Function '$func' definition not found"
    fi
    echo
done

header "Phase 3: Scanning for UI Function Misuse in Substitution Context"

# Find any use of UI functions inside functions that might be used in substitution
UI_FUNCTIONS=(
    "info"
    "success"
    "warning"
    "error"
    "progress"
    "echo"
    "printf"
)

echo "Checking for UI functions in potentially substituted functions..."

# Get all function definitions
ALL_FUNCTIONS=$(find /Users/moquette/.dotfiles -type f -name "*.sh" -exec grep -oE '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*\(\)' {} \; 2>/dev/null | sed 's/[[:space:]]*\(.*\)()/\1/' | sort -u)

for func in $ALL_FUNCTIONS; do
    # Skip very common functions that are unlikely to be problematic
    case "$func" in
        main|setup_*|install_*|test_*) continue ;;
    esac

    # Find function definition file
    FUNC_FILE=$(find /Users/moquette/.dotfiles -type f -name "*.sh" -exec grep -l "^[[:space:]]*${func}()" {} \; 2>/dev/null | head -1)

    if [[ -n "$FUNC_FILE" ]]; then
        # Check if this function is used in substitution
        SUBSTITUTION_CHECK=$(find /Users/moquette/.dotfiles -type f \( -name "*.sh" -o -name "bootstrap" -o -name "relink" -o -name "status" -o -name "install" \) -exec grep -l "\$.*${func}" {} \; 2>/dev/null || true)

        if [[ -n "$SUBSTITUTION_CHECK" ]]; then
            # Check if function contains UI output
            UI_OUTPUT=$(sed -n "/^[[:space:]]*${func}()/,/^}/p" "$FUNC_FILE" 2>/dev/null | grep -E "(info|success|warning|error|progress|echo|printf)" | grep -v ">&2" | head -3 || true)

            if [[ -n "$UI_OUTPUT" ]]; then
                critical "Function '$func' used in substitution but contains stdout output:"
                echo "  File: $FUNC_FILE"
                echo "  Used in: $SUBSTITUTION_CHECK"
                echo "  Problematic output:"
                echo "$UI_OUTPUT" | while read -r line; do
                    echo "    $line"
                done
                echo
            fi
        fi
    fi
done

header "Phase 4: Testing Current System"

echo "Testing current paths.sh functions for contamination..."

# Test discover_dotlocal_path
echo "Testing discover_dotlocal_path()..."
cd /Users/moquette/.dotfiles
source core/lib/paths.sh >/dev/null 2>&1

# Clear cache for clean test
clear_dotlocal_cache >/dev/null 2>&1

# Test with verbose=true (the dangerous case)
RESULT=$(discover_dotlocal_path "$HOME/.dotfiles" "true" 2>/dev/null)

if [[ "$RESULT" =~ ^/.*$ ]] && [[ ! "$RESULT" =~ $'\n' ]] && [[ ! "$RESULT" =~ "›" ]] && [[ ! "$RESULT" =~ "✓" ]]; then
    info_msg "discover_dotlocal_path() returns clean output: '$RESULT'"
else
    critical "discover_dotlocal_path() returns contaminated output: '$RESULT'"
fi

# Test resolve_dotlocal_path
echo "Testing resolve_dotlocal_path()..."
clear_dotlocal_cache >/dev/null 2>&1
RESULT2=$(resolve_dotlocal_path "$HOME/.dotfiles" "false" "true" 2>/dev/null)

if [[ "$RESULT2" =~ ^/.*$ ]] && [[ ! "$RESULT2" =~ $'\n' ]] && [[ ! "$RESULT2" =~ "›" ]] && [[ ! "$RESULT2" =~ "✓" ]]; then
    info_msg "resolve_dotlocal_path() returns clean output: '$RESULT2'"
else
    critical "resolve_dotlocal_path() returns contaminated output: '$RESULT2'"
fi

header "Phase 5: Summary"

echo "Audit Results:"
echo "  Critical Issues: $CRITICAL_COUNT"
echo "  Warnings: $WARNING_COUNT"
echo "  Info Messages: $INFO_COUNT"
echo

if [[ $CRITICAL_COUNT -gt 0 ]]; then
    echo -e "${RED}AUDIT FAILED: Critical contamination bugs found!${NC}"
    echo "These must be fixed immediately to prevent system corruption."
    exit 1
else
    echo -e "${GREEN}AUDIT PASSED: No critical contamination bugs detected.${NC}"
    echo "Command substitution is safe from stdout contamination."
fi