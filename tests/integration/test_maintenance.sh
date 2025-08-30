#!/usr/bin/env bash
#
# Test maintenance command functionality

# Source test framework
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$TESTS_DIR/../test_framework.sh"

# Test maintenance help
test_maintenance_help() {
    local output=$(dots maintenance --help 2>&1)
    assert_contains "$output" "Usage: dots maintenance" "Should show usage"
    assert_contains "$output" "--quick" "Should show quick option"
    assert_contains "$output" "--clean" "Should show clean option"
    assert_contains "$output" "--dry-run" "Should show dry-run option"
}

# Test dry-run mode
test_maintenance_dry_run() {
    # Create temp file to test cleaning
    touch "$DOTFILES_DIR/test.tmp"
    
    local output=$(dots maintenance --dry-run --clean 2>&1)
    assert_contains "$output" "DRY RUN MODE" "Should indicate dry-run mode"
    assert_contains "$output" "Would remove" "Should show what would be removed"
    
    # File should still exist after dry-run
    assert_exists "$DOTFILES_DIR/test.tmp" "Temp file should not be deleted in dry-run"
    
    # Clean up
    rm -f "$DOTFILES_DIR/test.tmp"
}

# Test clean functionality
test_maintenance_clean() {
    # Create various temp files
    touch "$DOTFILES_DIR/test.tmp"
    touch "$DOTFILES_DIR/test.bak"
    touch "$DOTFILES_DIR/test.orig"
    
    # Create .DS_Store
    touch "$DOTFILES_DIR/.DS_Store"
    
    # Run clean
    local output=$(dots maintenance --clean 2>&1)
    assert_contains "$output" "Cleaning temporary files" "Should show cleaning message"
    
    # Check files are removed
    assert_not_exists "$DOTFILES_DIR/test.tmp" "Temp file should be deleted"
    assert_not_exists "$DOTFILES_DIR/test.bak" "Backup file should be deleted"
    assert_not_exists "$DOTFILES_DIR/test.orig" "Orig file should be deleted"
    assert_not_exists "$DOTFILES_DIR/.DS_Store" ".DS_Store should be deleted"
}

# Test quick mode
test_maintenance_quick_mode() {
    local output=$(dots maintenance --quick --dry-run 2>&1)
    assert_contains "$output" "Skipping Homebrew updates" "Should skip Homebrew in quick mode"
    assert_not_contains "$output" "Updating Homebrew" "Should not update Homebrew"
}

# Test symlink health check
test_maintenance_symlink_check() {
    # Create a broken symlink for testing
    ln -sf /nonexistent/file "$HOME/.test_broken_link"
    
    local output=$(dots maintenance --dry-run 2>&1)
    assert_contains "$output" "Checking symlink health" "Should check symlinks"
    
    # Clean up
    rm -f "$HOME/.test_broken_link"
}

# Test repository sync skip with changes
test_maintenance_repo_sync_skip() {
    # Make a dummy change to trigger skip
    touch "$DOTFILES_DIR/dummy_change.txt"
    
    local output=$(dots maintenance --dry-run 2>&1)
    
    # Should detect and skip due to changes
    if git -C "$DOTFILES_DIR" diff --quiet; then
        assert_contains "$output" "already up to date" "Should check repo status"
    else
        assert_contains "$output" "uncommitted changes" "Should detect uncommitted changes"
    fi
    
    # Clean up
    rm -f "$DOTFILES_DIR/dummy_change.txt"
}

# Test health checks
test_maintenance_health_checks() {
    local output=$(dots maintenance --dry-run 2>&1)
    assert_contains "$output" "System health checks" "Should run health checks"
    assert_contains "$output" "Disk space" "Should check disk space"
    assert_contains "$output" "Shell configuration" "Should check shell config"
    assert_contains "$output" "Environment variables" "Should check env vars"
}

# Test summary reporting
test_maintenance_summary() {
    local output=$(dots maintenance --dry-run --quick 2>&1)
    assert_contains "$output" "Maintenance Summary" "Should show summary"
    assert_contains "$output" "Tasks run:" "Should show task count"
    assert_contains "$output" "Successful:" "Should show successful tasks"
    assert_contains "$output" "Completed in" "Should show completion time"
}

# Run tests
echo "=== Maintenance Command Tests ==="
run_test test_maintenance_help
run_test test_maintenance_dry_run  
run_test test_maintenance_clean
run_test test_maintenance_quick_mode
run_test test_maintenance_symlink_check
run_test test_maintenance_repo_sync_skip
run_test test_maintenance_health_checks
run_test test_maintenance_summary

# Print summary
print_test_summary