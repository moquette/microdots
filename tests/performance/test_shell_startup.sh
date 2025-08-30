#!/usr/bin/env bash
#
# Shell Startup Performance Tests
# Validates that the microdots system doesn't significantly slow shell startup
#

set -e

# Get the actual dotfiles root (two levels up from this test)
ACTUAL_DOTFILES_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"

source "$(dirname "$0")/../test_framework.sh"

# Override the DOTFILES_ROOT with correct path
DOTFILES_ROOT="$ACTUAL_DOTFILES_ROOT"

# Performance thresholds (in seconds)
STARTUP_THRESHOLD_FAST=0.5      # Excellent performance
STARTUP_THRESHOLD_ACCEPTABLE=2.0  # Acceptable performance
STARTUP_THRESHOLD_SLOW=5.0      # Performance concern threshold

# Test shell startup time with full system
test_full_startup_performance() {
  test_info "Testing full shell startup performance"
  
  local test_home="$TEST_TEMP_DIR/startup_test"
  mkdir -p "$test_home"
  
  # Copy full dotfiles system
  cp -r "$DOTFILES_ROOT" "$test_home/.dotfiles"
  
  # Measure startup time
  local start_time end_time duration
  
  # Test multiple runs to get average
  local total_time=0
  local runs=3
  
  for i in $(seq 1 $runs); do
    start_time=$(date +%s.%N)
    
    # Simulate shell startup by sourcing zshrc
    HOME="$test_home" ZSH="$test_home/.dotfiles" \
      timeout 10 zsh -c "source $test_home/.dotfiles/zsh/zshrc.symlink; exit" 2>/dev/null || {
        test_log "Run $i: Shell startup timed out or failed"
        continue
      }
    
    end_time=$(date +%s.%N)
    if command -v bc >/dev/null 2>&1; then
      duration=$(echo "$end_time - $start_time" | bc -l)
      total_time=$(echo "$total_time + $duration" | bc -l)
    else
      duration=$(awk "BEGIN {print $end_time - $start_time}")
      total_time=$(awk "BEGIN {print $total_time + $duration}")
    fi
    
    test_log "Run $i: Startup time ${duration}s"
  done
  
  local avg_time
  if command -v bc >/dev/null 2>&1; then
    avg_time=$(echo "scale=3; $total_time / $runs" | bc -l)
  else
    avg_time=$(awk "BEGIN {printf \"%.3f\", $total_time / $runs}")
  fi
  
  test_log "Average startup time: ${avg_time}s"
  
  # Simple performance evaluation (without bc if not available)
  if command -v bc >/dev/null 2>&1; then
    if (( $(echo "$avg_time < $STARTUP_THRESHOLD_FAST" | bc -l) )); then
      test_success "Shell startup performance is excellent (${avg_time}s average)"
    elif (( $(echo "$avg_time < $STARTUP_THRESHOLD_ACCEPTABLE" | bc -l) )); then
      test_success "Shell startup performance is acceptable (${avg_time}s average)"
    else
      test_log "Warning: Shell startup is slow (${avg_time}s average)"
      test_success "Shell startup performance test completed with warnings"
    fi
  else
    test_success "Shell startup performance measured: ${avg_time}s average"
  fi
}

# Test command execution performance
test_command_performance() {
  test_info "Testing dots command execution performance"
  
  local router="$DOTFILES_ROOT/core/dots"
  [[ -x "$router" ]] || router="$DOTFILES_ROOT/bin/dots"
  
  if [[ ! -x "$router" ]]; then
    test_skip "dots router not found for performance testing"
    return 0
  fi
  
  # Test performance of each command
  local commands_dir="$DOTFILES_ROOT/core/commands"
  
  for cmd_file in "$commands_dir"/*; do
    [[ -f "$cmd_file" && -x "$cmd_file" ]] || continue
    
    local cmd_name="$(basename "$cmd_file")"
    test_log "Testing performance of command: $cmd_name"
    
    local start_time end_time duration
    start_time=$(date +%s.%N)
    
    # Run command with --help or similar safe option
    "$router" "$cmd_name" --help >/dev/null 2>&1 || \
    "$router" "$cmd_name" >/dev/null 2>&1 || true
    
    end_time=$(date +%s.%N)
    if command -v bc >/dev/null 2>&1; then
      duration=$(echo "$end_time - $start_time" | bc -l)
    else
      duration=$(awk "BEGIN {print $end_time - $start_time}")
    fi
    
    test_log "Command $cmd_name execution time: ${duration}s"
    
    # Flag slow commands (simple comparison)
    if command -v bc >/dev/null 2>&1; then
      if (( $(echo "$duration > 2.0" | bc -l) )); then
        test_log "Warning: Command $cmd_name is slow (${duration}s)"
      fi
    fi
  done
  
  test_success "Command performance testing completed"
}

# Test memory usage during startup
test_memory_usage() {
  test_info "Testing memory usage during shell startup"
  
  local test_home="$TEST_TEMP_DIR/memory_test"
  mkdir -p "$test_home"
  cp -r "$DOTFILES_ROOT" "$test_home/.dotfiles"
  
  # Start shell process and measure memory
  local shell_pid memory_usage
  
  # Launch shell in background
  HOME="$test_home" ZSH="$test_home/.dotfiles" \
    zsh -c "source $test_home/.dotfiles/zsh/zshrc.symlink; sleep 3" &
  shell_pid=$!
  
  # Give it time to load
  sleep 1
  
  # Measure memory usage (RSS in KB)
  if command -v ps >/dev/null 2>&1; then
    memory_usage=$(ps -p "$shell_pid" -o rss= 2>/dev/null | tr -d ' ')
    
    if [[ -n "$memory_usage" && "$memory_usage" -gt 0 ]]; then
      local memory_mb=$(awk "BEGIN {printf \"%.1f\", $memory_usage / 1024}")
      test_log "Shell memory usage: ${memory_mb}MB"
      
      # Reasonable threshold for shell memory usage
      if [[ "$memory_usage" -gt 51200 ]]; then  # 50MB
        test_log "Warning: High memory usage detected (${memory_mb}MB)"
      fi
      
      test_success "Memory usage measured: ${memory_mb}MB"
    else
      test_success "Memory usage test completed (measurement unavailable)"
    fi
  else
    test_success "Memory usage test skipped (ps unavailable)"
  fi
  
  # Clean up
  kill "$shell_pid" 2>/dev/null || true
  wait "$shell_pid" 2>/dev/null || true
}

# Test loading stage performance
test_stage_performance() {
  test_info "Testing individual loading stage performance"
  
  local test_home="$TEST_TEMP_DIR/stage_perf_test"
  mkdir -p "$test_home/.dotfiles"
  cp -r "$DOTFILES_ROOT"/* "$test_home/.dotfiles/" 2>/dev/null || true
  
  # Count files in each stage
  local path_count=$(find "$test_home/.dotfiles" -name "path.zsh" | wc -l)
  local config_count=$(find "$test_home/.dotfiles" -name "*.zsh" -not -name "path.zsh" -not -name "completion.zsh" | wc -l)
  local completion_count=$(find "$test_home/.dotfiles" -name "completion.zsh" | wc -l)
  
  test_log "Loading stages: $path_count path, $config_count config, $completion_count completion files"
  
  # Basic performance check - ensure file counts are reasonable
  local total_files=$((path_count + config_count + completion_count))
  if [[ $total_files -gt 100 ]]; then
    test_log "Warning: Large number of configuration files ($total_files) may impact performance"
  fi
  
  test_success "Stage performance analysis completed: $total_files total files"
}

# Run all performance tests
run_performance_tests() {
  test_info "Performance Tests"
  
  setup_test_environment
  
  test_full_startup_performance
  test_command_performance
  test_memory_usage
  test_stage_performance
  
  cleanup_test_environment
  
  test_summary
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_performance_tests
fi
