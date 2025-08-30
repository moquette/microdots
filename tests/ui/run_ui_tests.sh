#!/usr/bin/env bash
#
# UI Test Suite Runner  
# Comprehensive testing of dotfiles UI system
#

set -e

# Get paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
DOTFILES_ROOT="$(dirname "$TESTS_DIR")"

# Colors for output
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    RESET=""
fi

# Test configuration
VERBOSE=false
QUICK=false
STOP_ON_FAIL=false

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quick)
            QUICK=true
            shift
            ;;
        --stop-on-fail)
            STOP_ON_FAIL=true
            shift
            ;;
        -h|--help)
            cat <<EOF
UI Test Suite Runner - Comprehensive dotfiles UI testing

Usage: $0 [options]

Options:
  -v, --verbose      Show detailed output from tests
  -q, --quick        Skip slower integration tests
  --stop-on-fail     Stop on first test failure
  -h, --help         Show this help

Test Categories:
  1. UI Function Tests    - Unit tests for individual UI functions
  2. UI Consistency Tests - Source code analysis for consistency
  3. Command Integration  - Real command output validation

This test suite validates the unified UI system you built, checking:
   All commands use UI functions (not raw echo)
   Consistent symbols across all commands (  ! :)  
   No extra spaces in success/error messages
   Proper header hierarchy (header vs subheader)
   Errors route to stderr correctly
   Color handling works properly
   Cross-command output consistency
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Test tracking
declare -a TEST_RESULTS=()
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Helper functions
log_info() {
    echo "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo "${GREEN}[PASS]${RESET} $1"
}

log_error() {
    echo "${RED}[FAIL]${RESET} $1"
}

log_warning() {
    echo "${YELLOW}[WARN]${RESET} $1"
}

log_section() {
    echo ""
    echo "${BOLD}${BLUE}=== $1 ===${RESET}"
    echo ""
}

run_test_suite() {
    local test_name="$1"
    local test_script="$2"
    local description="$3"
    
    log_info "Running: $test_name"
    [ "$VERBOSE" = true ] && echo "  Description: $description"
    
    local start_time=$(date +%s)
    local output
    local exit_code=0
    
    if [ "$VERBOSE" = true ]; then
        # Show output in real-time
        if "$test_script"; then
            exit_code=0
        else
            exit_code=$?
        fi
    else
        # Capture output
        if output=$("$test_script" 2>&1); then
            exit_code=0
        else
            exit_code=$?
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ $exit_code -eq 0 ]; then
        log_success "$test_name (${duration}s)"
        TEST_RESULTS+=("PASS:$test_name")
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
    else
        log_error "$test_name (${duration}s)"
        TEST_RESULTS+=("FAIL:$test_name")
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        
        # Show output on failure (even if not verbose)
        if [ "$VERBOSE" = false ] && [ -n "$output" ]; then
            echo "  Output:"
            echo "$output" | sed 's/^/    /'
        fi
        
        if [ "$STOP_ON_FAIL" = true ]; then
            echo ""
            log_error "Stopping due to test failure (--stop-on-fail)"
            exit 1
        fi
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo ""
}

# Validate test environment
validate_environment() {
    log_section "Environment Validation"
    
    # Check that test files exist
    local required_files=(
        "$SCRIPT_DIR/test_ui_functions.sh"
        "$SCRIPT_DIR/test_ui_consistency.sh"
        "$SCRIPT_DIR/test_command_integration.sh"
    )
    
    local missing_files=0
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Missing test file: $file"
            missing_files=$((missing_files + 1))
        else
            log_info "Found test file: $(basename "$file")"
        fi
    done
    
    if [ $missing_files -gt 0 ]; then
        log_error "$missing_files test files missing"
        exit 1
    fi
    
    # Check that core UI system exists
    if [ ! -f "$DOTFILES_ROOT/core/lib/ui.sh" ]; then
        log_error "UI library not found: $DOTFILES_ROOT/core/lib/ui.sh"
        exit 1
    else
        log_success "UI library found"
    fi
    
    # Check that commands exist
    local commands=("dots" "commands/bootstrap" "commands/install" "commands/relink" "commands/status")
    local missing_commands=0
    
    for cmd in "${commands[@]}"; do
        if [ ! -f "$DOTFILES_ROOT/core/$cmd" ]; then
            log_error "Missing command: core/$cmd"
            missing_commands=$((missing_commands + 1))
        fi
    done
    
    if [ $missing_commands -gt 0 ]; then
        log_error "$missing_commands commands missing"
        exit 1
    else
        log_success "All required commands found"
    fi
    
    echo ""
}

# Main test execution
main() {
    echo "${BOLD}>ê Dotfiles UI Test Suite${RESET}"
    echo "Comprehensive validation of unified UI system"
    echo ""
    
    # Validate environment first
    validate_environment
    
    # Test execution plan
    log_section "Test Execution Plan"
    
    if [ "$QUICK" = true ]; then
        log_warning "Quick mode: Skipping slower integration tests"
    fi
    
    if [ "$STOP_ON_FAIL" = true ]; then
        log_warning "Stop-on-fail: Will halt on first test failure"
    fi
    
    if [ "$VERBOSE" = true ]; then
        log_info "Verbose mode: Showing detailed test output"
    fi
    
    echo ""
    
    # Execute test suites
    log_section "Test Suite Execution"
    
    # 1. UI Function Unit Tests
    run_test_suite \
        "UI Function Tests" \
        "$SCRIPT_DIR/test_ui_functions.sh" \
        "Unit tests for individual UI library functions"
    
    # 2. UI Consistency Analysis  
    run_test_suite \
        "UI Consistency Tests" \
        "$SCRIPT_DIR/test_ui_consistency.sh" \
        "Source code analysis for UI consistency across commands"
    
    # 3. Command Integration Tests (may be slow)
    if [ "$QUICK" = false ]; then
        run_test_suite \
            "Command Integration Tests" \
            "$SCRIPT_DIR/test_command_integration.sh" \
            "Real command output validation and cross-command consistency"
    else
        log_info "Skipping Command Integration Tests (quick mode)"
        echo ""
    fi
    
    # Final Results
    log_section "Test Results Summary"
    
    echo "${BOLD}Results by Test Suite:${RESET}"
    for result in "${TEST_RESULTS[@]}"; do
        local status="${result%%:*}"
        local name="${result#*:}"
        
        if [ "$status" = "PASS" ]; then
            echo "  ${GREEN}${RESET} $name"
        else
            echo "  ${RED}${RESET} $name"
        fi
    done
    echo ""
    
    # Statistics
    echo "${BOLD}Overall Statistics:${RESET}"
    echo "  Total test suites: $TOTAL_TESTS"
    echo "  Passed:           $TOTAL_PASSED"
    echo "  Failed:           $TOTAL_FAILED"
    echo "  Success rate:     $([ $TOTAL_TESTS -gt 0 ] && echo "$((TOTAL_PASSED * 100 / TOTAL_TESTS))%" || echo "N/A")"
    echo ""
    
    # Final verdict
    if [ $TOTAL_FAILED -eq 0 ]; then
        echo "${BOLD}${GREEN}<‰ ALL UI TESTS PASSED!${RESET}"
        echo ""
        echo "Your unified UI system is working correctly:"
        echo "   All commands use UI functions consistently"
        echo "   Symbols are uniform across all commands"
        echo "   No extra spaces in messages"
        echo "   Proper header hierarchy"
        echo "   Errors route to stderr correctly"
        echo "   Cross-command consistency maintained"
        echo ""
        echo "The UI overhaul is complete and validated! =€"
        exit 0
    else
        echo "${BOLD}${RED}L UI TESTS FAILED${RESET}"
        echo ""
        echo "Issues found in the UI system:"
        
        for result in "${TEST_RESULTS[@]}"; do
            local status="${result%%:*}"
            local name="${result#*:}"
            
            if [ "$status" = "FAIL" ]; then
                echo "  " $name needs attention"
            fi
        done
        
        echo ""
        echo "${YELLOW}Common fixes needed:${RESET}"
        echo "  " Replace raw 'echo' with UI functions"
        echo "  " Remove extra spaces from success/error messages"
        echo "  " Use consistent symbols (  ! :) everywhere"
        echo "  " Ensure errors go to stderr"
        echo "  " Use 'header' once per command, 'subheader' for sections"
        echo ""
        echo "Run individual test suites for detailed error information:"
        echo "  $SCRIPT_DIR/test_ui_consistency.sh"
        echo "  $SCRIPT_DIR/test_ui_functions.sh" 
        echo "  $SCRIPT_DIR/test_command_integration.sh"
        
        exit 1
    fi
}

# Make test files executable
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Run main function
main "$@"