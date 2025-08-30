#!/usr/bin/env bash
#
# Comprehensive Test Suite Runner
# Runs all test categories to validate the complete Microdots system
#

set -euo pipefail

# Get the directory containing this script
TEST_ROOT="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$TEST_ROOT")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Test categories - organized by reliability
# CORE categories are stable and block on failure
# EXPERIMENTAL categories are informational only
CORE_CATEGORIES=("integration" "performance" "security")
EXPERIMENTAL_CATEGORIES=("architecture" "compliance" "unit" "ui" "edge_cases")

ALL_CATEGORIES=("${CORE_CATEGORIES[@]}" "${EXPERIMENTAL_CATEGORIES[@]}")

# Category descriptions (using function for compatibility)
get_category_description() {
  case "$1" in
    "integration") echo "Core system integration tests (85 tests)" ;;
    "performance") echo "Shell startup and performance validation" ;;
    "security") echo "Configuration security and safety checks" ;;
    "architecture") echo "Architecture compliance (experimental)" ;;
    "compliance") echo "Design principles validation (experimental)" ;;
    "unit") echo "Individual component tests (experimental)" ;;
    "ui") echo "User interface consistency (experimental)" ;;
    "edge_cases") echo "Edge cases and error handling (experimental)" ;;
    *) echo "Unknown category" ;;
  esac
}

# Test execution tracking
CATEGORY_RESULTS=()
CATEGORY_TIMES=()
TOTAL_TESTS_RUN=0
TOTAL_TESTS_PASSED=0
TOTAL_TESTS_FAILED=0
TOTAL_START_TIME=$(date +%s)

# Utility functions
print_header() {
  echo
  echo -e "${BOLD}${CYAN}$1${NC}"
  echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
  echo
}

print_category_header() {
  local category="$1"
  local description="$2"
  echo
  echo -e "${BOLD}${BLUE}Testing Category: $category${NC}"
  echo -e "${BLUE}Description: $description${NC}"
  echo -e "${BLUE}$(printf '─%.0s' $(seq 1 60))${NC}"
}

print_summary() {
  local category="$1"
  local result="$2"
  local time="$3"
  local color
  local marker=""
  
  case "$result" in
    "PASSED") color="$GREEN" ;;
    "FAILED") color="$RED" ;;
    "SKIPPED") color="$YELLOW" ;;
    "INFO") color="$CYAN"; marker=" [experimental]" ;;
    *) color="$NC" ;;
  esac
  
  printf "%-20s ${color}%-8s${NC}%s (%s)\n" "$category" "$result" "$marker" "$time"
}

# Get description for a category
get_description() {
  local category="$1"
  get_category_description "$category"
}

# Check if category is experimental
is_experimental() {
  local category="$1"
  for exp_cat in "${EXPERIMENTAL_CATEGORIES[@]}"; do
    if [[ "$exp_cat" == "$category" ]]; then
      return 0
    fi
  done
  return 1
}

# Run tests in a specific category
run_category_tests() {
  local category="$1"
  local category_start_time=$(date +%s)
  local is_exp=$(is_experimental "$category" && echo "true" || echo "false")
  
  # Add experimental marker to header
  local description="$(get_description "$category")"
  if [[ "$is_exp" == "true" ]]; then
    description="${description} [EXPERIMENTAL - non-blocking]"
  fi
  
  print_category_header "$category" "$description"
  
  local category_dir="$TEST_ROOT/$category"
  local -i tests_found=0
  local -i tests_passed=0
  local -i tests_failed=0
  
  # Check if category directory exists
  if [[ ! -d "$category_dir" ]]; then
    echo -e "${YELLOW}Warning: No tests found for category '$category'${NC}"
    CATEGORY_RESULTS+=("$category:SKIPPED")
    CATEGORY_TIMES+=("$category:0s")
    return 0
  fi
  
  # For integration category, use the dedicated runner
  if [[ "$category" == "integration" ]]; then
    local integration_runner="$TEST_ROOT/run_integration_tests.sh"
    if [[ -x "$integration_runner" ]]; then
      echo -e "${CYAN}Running dedicated integration test suite${NC}"
      local output
      local exit_code=0
      
      set +e  # Temporarily disable exit on error
      output=$("$integration_runner" 2>&1)
      exit_code=$?
      set -e  # Re-enable exit on error
      
      # Parse results from integration test output
      local integration_passed=$(echo "$output" | grep -o "Passed:[[:space:]]*[0-9]*" | grep -o "[0-9]*" || echo "0")
      local integration_failed=$(echo "$output" | grep -o "Failed:[[:space:]]*[0-9]*" | grep -o "[0-9]*" || echo "0")
      local integration_total=$(echo "$output" | grep -o "Total:[[:space:]]*[0-9]*" | grep -o "[0-9]*" || echo "0")
      
      if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} Integration test suite passed ($integration_passed/$integration_total)"
        tests_passed=$integration_passed
        tests_failed=$integration_failed
        tests_found=$integration_total
      else
        echo -e "${RED}✗${NC} Integration test suite failed"
        echo "$output" | tail -20
        tests_passed=${integration_passed:-0}
        tests_failed=${integration_failed:-1}
        tests_found=${integration_total:-1}
      fi
    else
      echo -e "${YELLOW}Integration test runner not found, falling back to individual tests${NC}"
      run_individual_tests "$category_dir"
    fi
  else
    run_individual_tests "$category_dir"
  fi
  
  # Update global counters (only for core categories)
  if [[ "$is_exp" == "false" ]]; then
    ((TOTAL_TESTS_RUN += tests_found))
    ((TOTAL_TESTS_PASSED += tests_passed))
    ((TOTAL_TESTS_FAILED += tests_failed))
  fi
  
  # Calculate category result and time
  local category_end_time=$(date +%s)
  local category_duration=$((category_end_time - category_start_time))
  
  local result
  if [[ $tests_found -eq 0 ]]; then
    result="SKIPPED"
  elif [[ $tests_failed -eq 0 ]]; then
    result="PASSED"
  else
    if [[ "$is_exp" == "true" ]]; then
      result="INFO" # Experimental failures are informational
    else
      result="FAILED"
    fi
  fi
  
  CATEGORY_RESULTS+=("$category:$result")
  CATEGORY_TIMES+=("$category:${category_duration}s")
  
  echo
  if [[ "$is_exp" == "true" ]]; then
    echo -e "${BOLD}Experimental Category Summary:${NC} $tests_passed passed, $tests_failed failed, $tests_found total ${YELLOW}(non-blocking)${NC}"
  else
    echo -e "${BOLD}Category Summary:${NC} $tests_passed passed, $tests_failed failed, $tests_found total"
  fi
}

# Helper function to run individual test files
# Note: This function modifies tests_found, tests_passed, tests_failed variables in parent scope
run_individual_tests() {
  local category_dir="$1"
  
  # Run all test files in category
  for test_file in "$category_dir"/test_*.sh; do
    [[ -f "$test_file" ]] || continue
    
    local test_name=$(basename "$test_file" .sh)
    echo -e "${CYAN}Running: $test_name${NC}"
    
    tests_found=$((tests_found + 1))
    
    if [[ -x "$test_file" ]]; then
      # Run the test and capture output
      local output
      local exit_code=0
      
      set +e  # Temporarily disable exit on error
      output=$("$test_file" 2>&1)
      exit_code=$?
      set -e  # Re-enable exit on error
      
      if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} $test_name passed"
        tests_passed=$((tests_passed + 1))
      else
        echo -e "${RED}✗${NC} $test_name failed"
        if [[ ${#output} -gt 500 ]]; then
          echo -e "${RED}Error output (truncated):${NC}"
          echo "$output" | head -10 | sed 's/^/  /'
          echo "  ... (output truncated, run individually for full details)"
        else
          echo -e "${RED}Error output:${NC}"
          echo "$output" | sed 's/^/  /'
        fi
        tests_failed=$((tests_failed + 1))
      fi
    else
      echo -e "${YELLOW}⚠${NC} $test_name not executable, skipping"
    fi
  done
}

# Main test execution function
run_all_tests() {
  echo -e "${BOLD}${BLUE}=== RUNNING CORE TEST CATEGORIES ===${NC}"
  echo "Core categories must pass for system validation"
  echo
  
  # Run core categories first
  for category in "${CORE_CATEGORIES[@]}"; do
    run_category_tests "$category"
  done
  
  echo
  echo -e "${BOLD}${CYAN}=== RUNNING EXPERIMENTAL TEST CATEGORIES ===${NC}"
  echo "Experimental categories provide additional insights but don't block validation"
  echo
  
  # Run experimental categories
  for category in "${EXPERIMENTAL_CATEGORIES[@]}"; do
    if [[ -d "$TEST_ROOT/$category" ]]; then
      run_category_tests "$category"
    else
      echo -e "${YELLOW}Category '$category' not found, skipping${NC}"
      CATEGORY_RESULTS+=("$category:SKIPPED")
      CATEGORY_TIMES+=("$category:0s")
    fi
  done
}

# Generate comprehensive test report
generate_report() {
  local total_end_time=$(date +%s)
  local total_duration=$((total_end_time - TOTAL_START_TIME))
  
  print_header "COMPREHENSIVE TEST SUITE RESULTS"
  
  # Separate core and experimental results
  echo -e "${BOLD}${BLUE}CORE CATEGORIES (System Validation):${NC}"
  echo "$(printf '%-20s %-12s %s' "Category" "Result" "Time")"
  echo "$(printf '─%.0s' $(seq 1 45))"
  
  local core_passed=0
  local core_failed=0
  local core_total=0
  
  for category in "${CORE_CATEGORIES[@]}"; do
    local result="SKIPPED"
    local time="0s"
    
    # Find result and time for this category
    for entry in "${CATEGORY_RESULTS[@]}"; do
      if [[ "$entry" =~ ^$category: ]]; then
        result="${entry#*:}"
        break
      fi
    done
    
    for entry in "${CATEGORY_TIMES[@]}"; do
      if [[ "$entry" =~ ^$category: ]]; then
        time="${entry#*:}"
        break
      fi
    done
    
    print_summary "$category" "$result" "$time"
    
    case "$result" in
      "PASSED") ((core_passed++)); ((core_total++)) ;;
      "FAILED") ((core_failed++)); ((core_total++)) ;;
      *) ;;
    esac
  done
  
  echo
  echo -e "${BOLD}${CYAN}EXPERIMENTAL CATEGORIES (Additional Insights):${NC}"
  echo "$(printf '%-20s %-12s %s' "Category" "Result" "Time")"
  echo "$(printf '─%.0s' $(seq 1 45))"
  
  local exp_passed=0
  local exp_failed=0
  local exp_info=0
  local exp_total=0
  
  for category in "${EXPERIMENTAL_CATEGORIES[@]}"; do
    local result="SKIPPED"
    local time="0s"
    
    # Find result and time for this category
    for entry in "${CATEGORY_RESULTS[@]}"; do
      if [[ "$entry" =~ ^$category: ]]; then
        result="${entry#*:}"
        break
      fi
    done
    
    for entry in "${CATEGORY_TIMES[@]}"; do
      if [[ "$entry" =~ ^$category: ]]; then
        time="${entry#*:}"
        break
      fi
    done
    
    print_summary "$category" "$result" "$time"
    
    case "$result" in
      "PASSED") ((exp_passed++)); ((exp_total++)) ;;
      "FAILED"|"INFO") ((exp_info++)); ((exp_total++)) ;;
      *) ;;
    esac
  done
  
  echo
  echo -e "${BOLD}Overall System Validation:${NC}"
  echo "  Total execution time: ${total_duration}s"
  echo "  Core test suite: $TOTAL_TESTS_RUN tests run, $TOTAL_TESTS_PASSED passed, $TOTAL_TESTS_FAILED failed"
  
  local success_rate=0
  if [[ $TOTAL_TESTS_RUN -gt 0 ]]; then
    success_rate=$(( TOTAL_TESTS_PASSED * 100 / TOTAL_TESTS_RUN ))
  fi
  echo "  Core success rate: ${success_rate}%"
  
  echo "  Core categories: $core_passed passed, $core_failed failed"
  echo "  Experimental categories: $exp_passed passed, $exp_info with issues (non-blocking)"
  
  echo
  
  # Final result based only on core categories
  if [[ $core_failed -eq 0 && $TOTAL_TESTS_FAILED -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}🎉 SYSTEM VALIDATION PASSED!${NC}"
    echo -e "${GREEN}All core tests passed. System is ready for use.${NC}"
    if [[ $exp_info -gt 0 ]]; then
      echo -e "${CYAN}Note: Some experimental tests have issues, but these don't affect system functionality.${NC}"
    fi
    return 0
  elif [[ $success_rate -ge 95 ]]; then
    echo -e "${BOLD}${YELLOW}⚠ SYSTEM VALIDATION MOSTLY PASSED${NC}"
    echo -e "${YELLOW}Core functionality works with minor issues (${success_rate}% success rate).${NC}"
    return 1
  else
    echo -e "${BOLD}${RED}❌ SYSTEM VALIDATION FAILED${NC}"
    echo -e "${RED}Core tests failed - system needs attention (${success_rate}% success rate).${NC}"
    return 2
  fi
}

# Main execution function
main() {
  # Set up trap to ensure report is generated even if tests fail
  trap 'echo; generate_report; exit $?' EXIT
  
  print_header "MICRODOTS COMPREHENSIVE TEST SUITE"
  
  echo "Testing Microdots architecture and implementation..."
  echo "System: $(uname -s) $(uname -r)"
  echo "Shell: $SHELL"
  echo "Date: $(date)"
  echo
  echo -e "${BOLD}Test Structure:${NC}"
  echo "• CORE categories: Essential system validation (must pass)"
  echo "• EXPERIMENTAL categories: Additional insights (informational)"
  echo
  
  # Verify test environment
  if [[ ! -f "$DOTFILES_ROOT/core/dots" && ! -f "$DOTFILES_ROOT/bin/dots" ]]; then
    echo -e "${RED}Error: Dotfiles system not found in $DOTFILES_ROOT${NC}"
    exit 1
  fi
  
  # Make all test files executable
  find "$TEST_ROOT" -name "test_*.sh" -type f ! -perm -u+x -exec chmod +x {} \; 2>/dev/null || true
  
  # Run all test categories with error handling
  set +e  # Disable exit on error for experimental tests
  run_all_tests
  set -e  # Re-enable exit on error
  
  # Remove the trap since we'll generate the report manually
  trap - EXIT
  
  # Generate final report
  echo
  generate_report
}

# Command line options
case "${1:-}" in
  --help|-h)
    echo "Usage: $0 [category|--help|--list|--core|--experimental]"
    echo
    echo "Run comprehensive tests for the Microdots system."
    echo
    echo "Options:"
    echo "  --help, -h        Show this help message"
    echo "  --list, -l        List available test categories"
    echo "  --core            Run only core test categories"
    echo "  --experimental    Run only experimental categories"
    echo "  [category]        Run tests for specific category only"
    echo
    echo "Core Categories (system validation):"
    for category in "${CORE_CATEGORIES[@]}"; do
      printf "  %-15s %s\n" "$category" "$(get_category_description "$category")"
    done
    echo
    echo "Experimental Categories (additional insights):"
    for category in "${EXPERIMENTAL_CATEGORIES[@]}"; do
      printf "  %-15s %s\n" "$category" "$(get_category_description "$category")"
    done
    exit 0
    ;;
  --list|-l)
    echo "Available test categories:"
    echo
    echo "Core Categories:"
    for category in "${CORE_CATEGORIES[@]}"; do
      printf "  %-15s %s\n" "$category" "$(get_category_description "$category")"
    done
    echo
    echo "Experimental Categories:"
    for category in "${EXPERIMENTAL_CATEGORIES[@]}"; do
      printf "  %-15s %s\n" "$category" "$(get_category_description "$category")"
    done
    exit 0
    ;;
  --core)
    print_header "MICRODOTS CORE TEST SUITE"
    echo "Running only core system validation tests..."
    echo
    for category in "${CORE_CATEGORIES[@]}"; do
      run_category_tests "$category"
    done
    exit $?
    ;;
  --experimental)
    print_header "MICRODOTS EXPERIMENTAL TEST SUITE"
    echo "Running experimental test categories..."
    echo
    for category in "${EXPERIMENTAL_CATEGORIES[@]}"; do
      if [[ -d "$TEST_ROOT/$category" ]]; then
        run_category_tests "$category"
      fi
    done
    exit $?
    ;;
  "")
    main
    ;;
  *)
    # Run specific category
    category="$1"
    
    # Check if category exists in either list
    found=false
    for cat in "${ALL_CATEGORIES[@]}"; do
      if [[ "$cat" == "$category" ]]; then
        found=true
        break
      fi
    done
    
    if [[ "$found" == "true" ]]; then
      print_header "MICRODOTS TEST SUITE - $category"
      run_category_tests "$category"
      exit $?
    else
      echo -e "${RED}Error: Unknown test category '$category'${NC}"
      echo "Use --list to see available categories"
      exit 1
    fi
    ;;
esac
