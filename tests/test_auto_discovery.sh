#!/usr/bin/env bash
# Test scenarios for the enhanced dotlocal auto-discovery system

set -e

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"

# Test data directory
TEST_DATA_DIR="/tmp/dotfiles_autodiscovery_test_$$"
TEST_DOTFILES="$TEST_DATA_DIR/dotfiles"
TEST_HOME="$TEST_DATA_DIR/home"

setup_test_environment() {
    # Clean up any previous test data
    rm -rf "$TEST_DATA_DIR"

    # Create test directories
    mkdir -p "$TEST_DOTFILES/core/lib"
    mkdir -p "$TEST_DOTFILES/core/commands"
    mkdir -p "$TEST_HOME"

    # Create minimal dotfiles structure
    echo '#!/usr/bin/env bash' > "$TEST_DOTFILES/core/lib/common.sh"
    echo 'expand_path() { echo "${1/#\~/$HOME}"; }' >> "$TEST_DOTFILES/core/lib/common.sh"
    echo 'info() { echo "[INFO] $1"; }' >> "$TEST_DOTFILES/core/lib/common.sh"
    echo 'success() { echo "[SUCCESS] $1"; }' >> "$TEST_DOTFILES/core/lib/common.sh"
    echo 'warning() { echo "[WARNING] $1"; }' >> "$TEST_DOTFILES/core/lib/common.sh"

    # Copy paths.sh to test location
    cp "$SCRIPT_DIR/../core/lib/paths.sh" "$TEST_DOTFILES/core/lib/paths.sh"

    # Set up test HOME
    export OLD_HOME="$HOME"
    export HOME="$TEST_HOME"

    # Create test cloud locations
    mkdir -p "$TEST_HOME/Library/Mobile Documents/com~apple~CloudDocs"
    mkdir -p "$TEST_HOME/Dropbox"
    mkdir -p "$TEST_HOME/Google Drive"
    mkdir -p "/tmp/volumes/My Shared Files"
}

cleanup_test_environment() {
    # Restore original HOME
    export HOME="$OLD_HOME"

    # Clean up test data
    rm -rf "$TEST_DATA_DIR"
}

test_level_1_dotfiles_conf() {
    test_start "Level 1: dotfiles.conf explicit configuration"

    # Create dotlocal directory and dotfiles.conf
    mkdir -p "$TEST_HOME/.test_dotlocal"
    echo 'DOTLOCAL="$HOME/.test_dotlocal"' > "$TEST_DOTFILES/dotfiles.conf"

    # Test discovery
    source "$TEST_DOTFILES/core/lib/paths.sh"
    local result=$(discover_dotlocal_path "$TEST_DOTFILES" false)
    local method=$(get_dotlocal_discovery_method)

    assert_equals "$result" "$TEST_HOME/.test_dotlocal" "Should discover path from dotfiles.conf"
    assert_equals "$method" "dotfiles.conf (explicit configuration)" "Should report correct method"

    test_pass
}

test_level_2_existing_symlink() {
    test_start "Level 2: existing .dotlocal symlink"

    # Clean up any dotfiles.conf
    rm -f "$TEST_DOTFILES/dotfiles.conf"

    # Create dotlocal directory and symlink
    mkdir -p "$TEST_HOME/.symlink_target"
    ln -sfn "$TEST_HOME/.symlink_target" "$TEST_DOTFILES/.dotlocal"

    # Clear cache and test discovery
    source "$TEST_DOTFILES/core/lib/paths.sh"
    clear_dotlocal_cache
    local result=$(discover_dotlocal_path "$TEST_DOTFILES" false)
    local method=$(get_dotlocal_discovery_method)

    assert_equals "$result" "$TEST_HOME/.symlink_target" "Should discover symlink target"
    assert_equals "$method" "existing .dotlocal symlink" "Should report correct method"

    test_pass
}

test_level_3_existing_directory() {
    test_start "Level 3: existing .dotlocal directory"

    # Clean up symlink
    rm -f "$TEST_DOTFILES/.dotlocal"

    # Create directory in dotfiles
    mkdir -p "$TEST_DOTFILES/.dotlocal"

    # Clear cache and test discovery
    source "$TEST_DOTFILES/core/lib/paths.sh"
    clear_dotlocal_cache
    local result=$(discover_dotlocal_path "$TEST_DOTFILES" false)
    local method=$(get_dotlocal_discovery_method)

    assert_equals "$result" "$TEST_DOTFILES/.dotlocal" "Should discover existing directory"
    assert_equals "$method" "existing .dotlocal directory" "Should report correct method"

    test_pass
}

test_level_4_standard_location() {
    test_start "Level 4: standard ~/.dotlocal directory"

    # Clean up existing directory
    rm -rf "$TEST_DOTFILES/.dotlocal"

    # Create standard location
    mkdir -p "$TEST_HOME/.dotlocal"

    # Clear cache and test discovery
    source "$TEST_DOTFILES/core/lib/paths.sh"
    clear_dotlocal_cache
    local result=$(discover_dotlocal_path "$TEST_DOTFILES" false)
    local method=$(get_dotlocal_discovery_method)

    assert_equals "$result" "$TEST_HOME/.dotlocal" "Should discover standard location"
    assert_equals "$method" "standard ~/.dotlocal directory" "Should report correct method"

    test_pass
}

test_level_5_cloud_discovery() {
    test_start "Level 5: cloud storage auto-discovery"

    # Clean up standard location
    rm -rf "$TEST_HOME/.dotlocal"

    # Create iCloud location
    mkdir -p "$TEST_HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal"

    # Clear cache and test discovery
    source "$TEST_DOTFILES/core/lib/paths.sh"
    clear_dotlocal_cache
    local result=$(discover_dotlocal_path "$TEST_DOTFILES" false)
    local method=$(get_dotlocal_discovery_method)

    assert_equals "$result" "$TEST_HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal" "Should discover iCloud location"
    assert_equals "$method" "cloud storage auto-discovery" "Should report correct method"

    test_pass
}

test_infrastructure_setup() {
    test_start "Infrastructure setup functionality"

    # Create test dotlocal directory
    local test_dotlocal="$TEST_HOME/.infrastructure_test"
    mkdir -p "$test_dotlocal"

    # Test infrastructure setup
    source "$TEST_DOTFILES/core/lib/paths.sh"
    setup_dotlocal_infrastructure "$test_dotlocal" "$TEST_DOTFILES" "false"

    # Verify symlinks were created
    assert_true "[ -L '$TEST_DOTFILES/.dotlocal' ]" "Should create .dotlocal symlink"
    assert_true "[ -L '$test_dotlocal/core' ]" "Should create core symlink"

    # Verify symlink targets
    local dotlocal_target=$(readlink "$TEST_DOTFILES/.dotlocal")
    local core_target=$(readlink "$test_dotlocal/core")

    assert_equals "$dotlocal_target" "$test_dotlocal" "dotlocal symlink should point to correct location"
    assert_equals "$core_target" "$TEST_DOTFILES/core" "core symlink should point to dotfiles core"

    test_pass
}

test_precedence_order() {
    test_start "Precedence order validation"

    # Set up all levels
    echo 'DOTLOCAL="$HOME/.config_level"' > "$TEST_DOTFILES/dotfiles.conf"
    mkdir -p "$TEST_HOME/.config_level"

    mkdir -p "$TEST_HOME/.symlink_level"
    ln -sfn "$TEST_HOME/.symlink_level" "$TEST_DOTFILES/.dotlocal"

    mkdir -p "$TEST_HOME/.dotlocal"
    mkdir -p "$TEST_HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal"

    # Test that config level wins
    source "$TEST_DOTFILES/core/lib/paths.sh"
    clear_dotlocal_cache
    local result=$(discover_dotlocal_path "$TEST_DOTFILES" false)

    assert_equals "$result" "$TEST_HOME/.config_level" "Config level should have highest precedence"

    # Remove config and test symlink level
    rm -f "$TEST_DOTFILES/dotfiles.conf"
    unset DOTLOCAL
    clear_dotlocal_cache
    result=$(discover_dotlocal_path "$TEST_DOTFILES" false)

    assert_equals "$result" "$TEST_HOME/.symlink_level" "Symlink level should be second precedence"

    test_pass
}

test_error_handling() {
    test_start "Error handling and edge cases"

    # Test with broken symlink
    rm -rf "$TEST_HOME/.symlink_level"  # Remove target but keep symlink
    source "$TEST_DOTFILES/core/lib/paths.sh"
    clear_dotlocal_cache
    local result=$(discover_dotlocal_path "$TEST_DOTFILES" false)

    # Should fall back to next level (standard location)
    assert_equals "$result" "$TEST_HOME/.dotlocal" "Should handle broken symlinks gracefully"

    # Test with no locations available
    rm -rf "$TEST_DOTFILES/.dotlocal"
    rm -rf "$TEST_HOME/.dotlocal"
    rm -rf "$TEST_HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal"

    clear_dotlocal_cache
    result=$(discover_dotlocal_path "$TEST_DOTFILES" false)

    assert_equals "$result" "" "Should return empty when no locations found"

    test_pass
}

test_resolve_with_creation() {
    test_start "Resolve with auto-creation"

    # Clear all locations
    rm -rf "$TEST_DOTFILES/.dotlocal"
    rm -rf "$TEST_HOME/.dotlocal"

    # Test resolve with creation
    source "$TEST_DOTFILES/core/lib/paths.sh"
    clear_dotlocal_cache
    local result=$(resolve_dotlocal_path "$TEST_DOTFILES" "true" false)

    assert_equals "$result" "$TEST_HOME/.dotlocal" "Should create default location"
    assert_true "[ -d '$TEST_HOME/.dotlocal' ]" "Should actually create the directory"
    assert_true "[ -L '$TEST_DOTFILES/.dotlocal' ]" "Should create .dotlocal symlink"
    assert_true "[ -L '$TEST_HOME/.dotlocal/core' ]" "Should create core symlink"

    test_pass
}

# Main test execution
main() {
    test_suite_start "Dotlocal Auto-Discovery System Tests"

    setup_test_environment

    # Run all tests
    test_level_1_dotfiles_conf
    test_level_2_existing_symlink
    test_level_3_existing_directory
    test_level_4_standard_location
    test_level_5_cloud_discovery
    test_infrastructure_setup
    test_precedence_order
    test_error_handling
    test_resolve_with_creation

    cleanup_test_environment

    test_suite_end
}

# Run tests if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi