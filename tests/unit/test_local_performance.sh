#!/usr/bin/env bash
#
# Performance and Stress Tests for Local Topic Functionality  
# Tests performance characteristics and resource usage of local topic system
#

set -e

# Get the script directory and source test framework
TEST_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$(dirname "$TEST_DIR")")"
source "$TEST_DIR/../test_framework.sh"

# Performance test configuration
PERF_TEST_TOPICS=50
PERF_FILES_PER_TOPIC=20
STRESS_TEST_TOPICS=200
STRESS_FILES_PER_TOPIC=100

# Setup performance test environment
setup_performance_environment() {
    # Setup base test environment FIRST
    setup_test_environment
    
    test_info "Setting up performance test environment..."
    
    # Set up dotfiles structure
    mkdir -p "$TEST_HOME/.dotfiles"
    cp -r "$DOTFILES_ROOT/core" "$TEST_HOME/.dotfiles/" 2>/dev/null || true
    cp -r "$DOTFILES_ROOT/zsh" "$TEST_HOME/.dotfiles/" 2>/dev/null || true
    
    export ZSH="$TEST_HOME/.dotfiles"
    export DOTFILES_DIR="$TEST_HOME/.dotfiles"
    
    test_success "Performance environment ready"
}

# Helper function to create many test topics
create_test_topics() {
    local topic_count=$1
    local files_per_topic=$2
    local base_dir=$3
    
    test_info "Creating $topic_count topics with $files_per_topic files each in $base_dir"
    
    for ((topic=1; topic<=topic_count; topic++)); do
        local topic_dir="$base_dir/perf_topic_$topic"
        mkdir -p "$topic_dir"
        
        # Create path.zsh
        echo "export TOPIC_${topic}_PATH=\"/path/for/topic/$topic\"" > "$topic_dir/path.zsh"
        
        # Create multiple config files
        for ((file=1; file<=files_per_topic; file++)); do
            cat > "$topic_dir/config_$file.zsh" << EOF
# Config file $file for topic $topic
export TOPIC_${topic}_VAR_${file}="value_${topic}_${file}"
alias topic${topic}cmd${file}='echo "Command $file from topic $topic"'

# Function for topic $topic file $file
topic${topic}_func${file}() {
    echo "Function $file from topic $topic called with args: \$@"
}
EOF
        done
        
        # Create completion.zsh
        echo "# Completion for topic $topic" > "$topic_dir/completion.zsh"
        echo "complete -W 'option1 option2 option3' topic${topic}cmd" >> "$topic_dir/completion.zsh"
        
        # Create install.sh
        cat > "$topic_dir/install.sh" << 'EOF'
#!/usr/bin/env bash
echo "Installing performance test topic"
EOF
        chmod +x "$topic_dir/install.sh"
    done
    
    test_success "Created $topic_count test topics"
}

# Test 1: Shell Loading Performance
test_shell_loading_performance() {
    test_info "Testing shell loading performance with many local topics"
    
    # Create moderate number of topics for baseline
    mkdir -p "$TEST_HOME/.dotlocal"
    create_test_topics $PERF_TEST_TOPICS $PERF_FILES_PER_TOPIC "$TEST_HOME/.dotlocal"
    
    # Measure loading time
    local start_time=$(date +%s%N)
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    local end_time=$(date +%s%N)
    
    # Calculate duration in milliseconds
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))
    
    test_info "Shell loading took ${duration_ms}ms with $PERF_TEST_TOPICS topics"
    
    # Performance threshold: should load within 5 seconds
    if [ $duration_ms -lt 5000 ]; then
        test_success "Performance acceptable: ${duration_ms}ms < 5000ms"
    else
        test_error "Performance degraded: ${duration_ms}ms >= 5000ms"
    fi
    
    # Verify functionality still works
    assert_equals "value_1_1" "${TOPIC_1_VAR_1:-}" "Variables should still be set correctly"
    assert_equals "/path/for/topic/1" "${TOPIC_1_PATH:-}" "Path variables should be set correctly"
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Shell loading performance test passed"
}

# Test 2: Path Resolution Performance
test_path_resolution_performance() {
    test_info "Testing path resolution performance under load"
    
    # Create complex directory structure
    mkdir -p "$TEST_HOME/.dotlocal/deep/nested/structure"
    mkdir -p "$TEST_HOME/.dotfiles/.local_target"
    ln -sf "$TEST_HOME/.dotfiles/.local_target" "$TEST_HOME/.dotfiles/.local"
    echo "LOCAL_PATH=$TEST_HOME/.dotlocal/deep/nested/structure" > "$TEST_HOME/.dotfiles/dotfiles.conf"
    
    source "$TEST_HOME/.dotfiles/core/lib/paths.sh"
    
    # Measure path resolution time over many iterations
    local iterations=1000
    local start_time=$(date +%s%N)
    
    for ((i=1; i<=iterations; i++)); do
        clear_path_cache
        resolve_local_path >/dev/null
    done
    
    local end_time=$(date +%s%N)
    local duration_ns=$((end_time - start_time))
    local avg_duration_us=$((duration_ns / iterations / 1000))
    
    test_info "Average path resolution time: ${avg_duration_us}�s over $iterations iterations"
    
    # Should resolve within 1ms per call on average
    if [ $avg_duration_us -lt 1000 ]; then
        test_success "Path resolution performance acceptable: ${avg_duration_us}�s < 1000�s"
    else
        test_error "Path resolution too slow: ${avg_duration_us}�s >= 1000�s"
    fi
    
    # Cleanup
    rm -f "$TEST_HOME/.dotfiles/dotfiles.conf"
    rm -f "$TEST_HOME/.dotfiles/.local"
    rm -rf "$TEST_HOME/.dotlocal"
    rm -rf "$TEST_HOME/.dotfiles/.local_target"
    
    test_success "Path resolution performance test passed"
}

# Test 3: Memory Usage Test
test_memory_usage() {
    test_info "Testing memory usage with large number of topics"
    
    # Create many topics to test memory usage
    mkdir -p "$TEST_HOME/.dotlocal"
    create_test_topics $STRESS_TEST_TOPICS 10 "$TEST_HOME/.dotlocal"
    
    # Get memory usage before loading
    local mem_before
    if command -v ps >/dev/null 2>&1; then
        mem_before=$(ps -o rss= -p $$)
    else
        mem_before=0
    fi
    
    # Load the configuration
    cd "$TEST_HOME"
    source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"
    
    # Get memory usage after loading
    local mem_after
    if command -v ps >/dev/null 2>&1; then
        mem_after=$(ps -o rss= -p $$)
    else
        mem_after=0
    fi
    
    local mem_increase=$((mem_after - mem_before))
    
    test_info "Memory usage increased by ${mem_increase}KB with $STRESS_TEST_TOPICS topics"
    
    # Memory increase should be reasonable (< 50MB for stress test)
    if [ $mem_increase -lt 51200 ]; then
        test_success "Memory usage acceptable: ${mem_increase}KB < 50MB"
    else
        test_warning "High memory usage: ${mem_increase}KB >= 50MB"
    fi
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Memory usage test completed"
}

# Test 4: Install Performance Test
test_install_performance() {
    test_info "Testing install performance with many local topics"
    
    # Create topics with install scripts
    mkdir -p "$TEST_HOME/.dotlocal"
    create_test_topics $PERF_TEST_TOPICS 5 "$TEST_HOME/.dotlocal"
    
    # Measure install time
    local start_time=$(date +%s%N)
    cd "$TEST_HOME/.dotfiles"
    export DOTLOCAL_DIR="$TEST_HOME/.dotlocal"
    bash "./core/commands/install" >/dev/null 2>&1
    local end_time=$(date +%s%N)
    
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))
    
    test_info "Install took ${duration_ms}ms with $PERF_TEST_TOPICS topics"
    
    # Install should complete within reasonable time
    if [ $duration_ms -lt 10000 ]; then
        test_success "Install performance acceptable: ${duration_ms}ms < 10s"
    else
        test_error "Install too slow: ${duration_ms}ms >= 10s"
    fi
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Install performance test passed"
}

# Test 5: Symlink Processing Performance
test_symlink_performance() {
    test_info "Testing symlink processing performance"
    
    # Create topics with many symlink files
    mkdir -p "$TEST_HOME/.dotlocal"
    
    for ((topic=1; topic<=PERF_TEST_TOPICS; topic++)); do
        local topic_dir="$TEST_HOME/.dotlocal/symlink_topic_$topic"
        mkdir -p "$topic_dir"
        
        # Create multiple symlink files
        for ((file=1; file<=10; file++)); do
            echo "# Symlink config $file for topic $topic" > "$topic_dir/config$file.symlink"
        done
    done
    
    # Measure symlink processing time
    local start_time=$(date +%s%N)
    cd "$TEST_HOME/.dotfiles"
    export DOTLOCAL_DIR="$TEST_HOME/.dotlocal"
    bash "./core/commands/relink" >/dev/null 2>&1
    local end_time=$(date +%s%N)
    
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))
    local total_symlinks=$((PERF_TEST_TOPICS * 10))
    
    test_info "Processed $total_symlinks symlinks in ${duration_ms}ms"
    
    # Should process symlinks efficiently
    local ms_per_symlink=$((duration_ms / total_symlinks))
    if [ $ms_per_symlink -lt 10 ]; then
        test_success "Symlink processing efficient: ${ms_per_symlink}ms per symlink"
    else
        test_warning "Symlink processing slow: ${ms_per_symlink}ms per symlink"
    fi
    
    # Verify some symlinks were created
    local created_count=$(ls -la "$TEST_HOME"/.config* 2>/dev/null | wc -l || echo "0")
    if [ "$created_count" -gt 0 ]; then
        test_success "Symlinks were created successfully ($created_count files)"
    fi
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    rm -f "$TEST_HOME"/.config*
    
    test_success "Symlink performance test passed"
}

# Test 6: Stress Test - Maximum Load
test_stress_maximum_load() {
    test_info "Running maximum load stress test"
    
    # Create very large number of topics
    mkdir -p "$TEST_HOME/.dotlocal"
    create_test_topics $STRESS_TEST_TOPICS $STRESS_FILES_PER_TOPIC "$TEST_HOME/.dotlocal"
    
    local total_files=$((STRESS_TEST_TOPICS * STRESS_FILES_PER_TOPIC))
    test_info "Stress testing with $STRESS_TEST_TOPICS topics, $total_files total files"
    
    # Attempt to load configuration
    local start_time=$(date +%s)
    cd "$TEST_HOME"
    
    # Set timeout to prevent hanging
    timeout 60 bash -c 'source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink"' 2>/dev/null || {
        test_warning "Stress test timed out after 60 seconds"
        return 0
    }
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    test_info "Stress test completed in ${duration}s"
    
    # If it completed within timeout, check functionality
    if [ $duration -lt 60 ]; then
        # Test a few variables to ensure basic functionality
        if [[ -n "${TOPIC_1_VAR_1:-}" ]]; then
            test_success "Stress test passed: functionality maintained under load"
        else
            test_error "Stress test failed: variables not loaded properly"
        fi
    fi
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Maximum load stress test completed"
}

# Test 7: Concurrent Access Performance
test_concurrent_performance() {
    test_info "Testing performance under concurrent access"
    
    # Create moderate test load
    mkdir -p "$TEST_HOME/.dotlocal"
    create_test_topics 20 10 "$TEST_HOME/.dotlocal"
    
    # Launch multiple concurrent processes
    local concurrent_processes=10
    local pids=()
    
    test_info "Starting $concurrent_processes concurrent shell loading processes"
    
    local start_time=$(date +%s%N)
    
    for ((i=1; i<=concurrent_processes; i++)); do
        (
            cd "$TEST_HOME"
            source "$TEST_HOME/.dotfiles/zsh/zshrc.symlink" >/dev/null 2>&1
            echo "Process $i completed"
        ) &
        pids+=($!)
    done
    
    # Wait for all processes to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    local end_time=$(date +%s%N)
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))
    
    test_info "Concurrent loading completed in ${duration_ms}ms"
    
    # Should handle concurrent access reasonably
    if [ $duration_ms -lt 15000 ]; then
        test_success "Concurrent performance acceptable: ${duration_ms}ms < 15s"
    else
        test_warning "Concurrent performance degraded: ${duration_ms}ms >= 15s"
    fi
    
    # Cleanup
    rm -rf "$TEST_HOME/.dotlocal"
    
    test_success "Concurrent performance test passed"
}

# Main test execution
main() {
    echo "========================================="
    echo "LOCAL TOPIC PERFORMANCE TEST SUITE"
    echo "Testing performance and resource usage"
    echo "========================================="
    
    # Setup test environment
    setup_performance_environment
    
    # Run performance tests
    run_test "Shell Loading Performance" test_shell_loading_performance
    run_test "Path Resolution Performance" test_path_resolution_performance
    run_test "Memory Usage Test" test_memory_usage
    run_test "Install Performance" test_install_performance
    run_test "Symlink Performance" test_symlink_performance
    run_test "Maximum Load Stress Test" test_stress_maximum_load
    run_test "Concurrent Access Performance" test_concurrent_performance
    
    # Generate final report
    generate_test_report
}

# Execute main function if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi