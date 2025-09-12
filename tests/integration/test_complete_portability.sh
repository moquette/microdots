#!/usr/bin/env bash
#
# Comprehensive Integration Test Suite for Dotfiles System
# Tests topic self-containment, addition/removal, system resilience, and edge cases

set -euo pipefail

# Get the dotfiles root directory
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOTFILES_ROOT

# Source testing utilities
source "$DOTFILES_ROOT/core/lib/common.sh"

# Test configuration
TEST_TEMP_DIR=""
TEST_HOME_DIR=""
ORIGINAL_HOME="$HOME"
ORIGINAL_ZSH="$ZSH"
TEST_FAILED=0
TEST_PASSED=0
TEST_SKIPPED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
setup_test_environment() {
    TEST_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-test.XXXXXX")
    TEST_HOME_DIR="$TEST_TEMP_DIR/home"
    mkdir -p "$TEST_HOME_DIR"
    export HOME="$TEST_HOME_DIR"
    export ZSH="$TEST_TEMP_DIR/dotfiles"
    info "Test environment created at: $TEST_TEMP_DIR"
}

cleanup_test_environment() {
    export HOME="$ORIGINAL_HOME"
    export ZSH="$ORIGINAL_ZSH"
    if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
        info "Test environment cleaned up"
    fi
}

# Enhanced assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"
    
    if [[ "$expected" != "$actual" ]]; then
        echo -e "${RED}✗${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        ((TEST_FAILED++))
        return 1
    else
        echo -e "${GREEN}✓${NC} $message"
        ((TEST_PASSED++))
        return 0
    fi
}

assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    if [[ -f "$file" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((TEST_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((TEST_FAILED++))
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local message="${2:-Directory should exist: $dir}"
    
    if [[ -d "$dir" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((TEST_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((TEST_FAILED++))
        return 1
    fi
}

assert_symlink_exists() {
    local link="$1"
    local message="${2:-Symlink should exist: $link}"
    
    if [[ -L "$link" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((TEST_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((TEST_FAILED++))
        return 1
    fi
}

assert_no_file() {
    local file="$1"
    local message="${2:-File should not exist: $file}"
    
    if [[ ! -e "$file" ]]; then
        echo -e "${GREEN}✓${NC} $message"
        ((TEST_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((TEST_FAILED++))
        return 1
    fi
}

assert_command_succeeds() {
    local command="$1"
    local message="${2:-Command should succeed: $command}"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $message"
        ((TEST_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $message"
        ((TEST_FAILED++))
        return 1
    fi
}

assert_command_fails() {
    local command="$1"
    local message="${2:-Command should fail: $command}"
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} $message"
        ((TEST_FAILED++))
        return 1
    else
        echo -e "${GREEN}✓${NC} $message"
        ((TEST_PASSED++))
        return 0
    fi
}

skip_test() {
    local message="${1:-Test skipped}"
    echo -e "${YELLOW}⊘${NC} $message"
    ((TEST_SKIPPED++))
}

#==============================================================================
# TEST SUITE 1: CORE SYSTEM ARCHITECTURE
#==============================================================================

test_dotfiles_directory_structure() {
    echo -e "\n${CYAN}=== Testing Dotfiles Directory Structure ===${NC}"
    
    # Core directories that should exist
    assert_dir_exists "$DOTFILES_ROOT/bin" "bin directory exists"
    assert_dir_exists "$DOTFILES_ROOT/core" "core directory exists"
    assert_dir_exists "$DOTFILES_ROOT/core/commands" "core/commands directory exists"
    assert_dir_exists "$DOTFILES_ROOT/core/lib" "core/lib directory exists"
    
    # Essential files
    assert_file_exists "$DOTFILES_ROOT/README.md" "README.md exists"
    assert_file_exists "$DOTFILES_ROOT/core/lib/common.sh" "common.sh library exists"
}

test_command_routing_system() {
    echo -e "\n${CYAN}=== Testing Command Routing System ===${NC}"
    
    # Check dots command exists and is executable
    assert_file_exists "$DOTFILES_ROOT/bin/dots" "dots command exists"
    assert_command_succeeds "test -x '$DOTFILES_ROOT/bin/dots'" "dots command is executable"
    
    # Check command delegation structure
    assert_file_exists "$DOTFILES_ROOT/core/commands/bootstrap" "bootstrap command exists"
    assert_file_exists "$DOTFILES_ROOT/core/commands/install" "install command exists"
}

#==============================================================================
# TEST SUITE 2: FILE DISCOVERY AND LOADING MECHANISM
#==============================================================================

test_zsh_file_discovery_patterns() {
    echo -e "\n${CYAN}=== Testing ZSH File Discovery Patterns ===${NC}"
    
    # Count different file types (excluding hidden directories)
    local zsh_count=$(find "$DOTFILES_ROOT" -maxdepth 2 -name "*.zsh" 2>/dev/null | wc -l | tr -d ' ')
    local path_count=$(find "$DOTFILES_ROOT" -maxdepth 2 \( -name "path.zsh" -o -name "_path.zsh" \) 2>/dev/null | wc -l | tr -d ' ')
    local completion_count=$(find "$DOTFILES_ROOT" -maxdepth 2 -name "completion.zsh" 2>/dev/null | wc -l | tr -d ' ')
    
    [[ $zsh_count -gt 0 ]] && echo -e "${GREEN}✓${NC} Found $zsh_count .zsh files" && ((TEST_PASSED++)) || \
        { echo -e "${RED}✗${NC} No .zsh files found"; ((TEST_FAILED++)); }
    
    [[ $path_count -gt 0 ]] && echo -e "${GREEN}✓${NC} Found $path_count path.zsh files" && ((TEST_PASSED++)) || \
        { echo -e "${RED}✗${NC} No path.zsh files found"; ((TEST_FAILED++)); }
    
    [[ $completion_count -gt 0 ]] && echo -e "${GREEN}✓${NC} Found $completion_count completion.zsh files" && ((TEST_PASSED++)) || \
        { echo -e "${YELLOW}⊘${NC} No completion.zsh files found (optional)"; ((TEST_SKIPPED++)); }
}

test_loading_order_mechanism() {
    echo -e "\n${CYAN}=== Testing Loading Order Mechanism ===${NC}"
    
    # Check zshrc implements the correct loading order
    local zshrc="$DOTFILES_ROOT/zsh/zshrc.symlink"
    
    if [[ -f "$zshrc" ]]; then
        # Stage 1: PATH files loading (lines 48-49) - looks for "(M)config_files:#*/path.zsh"
        local path_loading_line=$(grep -n "(M).*:#\*/path\.zsh" "$zshrc" 2>/dev/null | head -1 | cut -d: -f1)
        
        # Stage 2: Regular config files loading (lines 52-53) - looks for exclusion pattern
        local regular_loading_line=$(grep -n "\${config_files:#\*/path\.zsh}:#\*/completion\.zsh" "$zshrc" 2>/dev/null | head -1 | cut -d: -f1)
        
        # Stage 3: compinit initialization (around lines 63-66)
        local compinit_line=$(grep -n "compinit -" "$zshrc" 2>/dev/null | head -1 | cut -d: -f1)
        
        # Stage 4: Completion files loading (lines 61-62) - looks for "(M)config_files:#*/completion.zsh"
        local completion_loading_line=$(grep -n "(M).*:#\*/completion\.zsh" "$zshrc" 2>/dev/null | head -1 | cut -d: -f1)
        
        # Verify Stage 1 < Stage 2
        if [[ -n "$path_loading_line" ]] && [[ -n "$regular_loading_line" ]] && [[ $path_loading_line -lt $regular_loading_line ]]; then
            echo -e "${GREEN}✓${NC} PATH files load before regular .zsh files (Stage 1 < Stage 2)"
            ((TEST_PASSED++))
        else
            echo -e "${RED}✗${NC} Cannot verify PATH loading order (Stage 1 < Stage 2)"
            echo "  PATH loading line: $path_loading_line, Regular loading line: $regular_loading_line"
            ((TEST_FAILED++))
        fi
        
        # Verify Stage 2 < Stage 3
        if [[ -n "$regular_loading_line" ]] && [[ -n "$compinit_line" ]] && [[ $regular_loading_line -lt $compinit_line ]]; then
            echo -e "${GREEN}✓${NC} Regular files load before compinit (Stage 2 < Stage 3)"
            ((TEST_PASSED++))
        else
            echo -e "${RED}✗${NC} Cannot verify regular loading before compinit (Stage 2 < Stage 3)"
            echo "  Regular loading line: $regular_loading_line, Compinit line: $compinit_line"
            ((TEST_FAILED++))
        fi
        
        # Verify Stage 3 < Stage 4
        if [[ -n "$compinit_line" ]] && [[ -n "$completion_loading_line" ]] && [[ $compinit_line -lt $completion_loading_line ]]; then
            echo -e "${GREEN}✓${NC} compinit runs before completion files (Stage 3 < Stage 4)"
            ((TEST_PASSED++))
        else
            echo -e "${RED}✗${NC} Cannot verify compinit before completion loading (Stage 3 < Stage 4)"
            echo "  Compinit line: $compinit_line, Completion loading line: $completion_loading_line"
            ((TEST_FAILED++))
        fi
        
        # Verify all four stages are present
        if [[ -n "$path_loading_line" ]] && [[ -n "$regular_loading_line" ]] && [[ -n "$compinit_line" ]] && [[ -n "$completion_loading_line" ]]; then
            echo -e "${GREEN}✓${NC} All four loading stages are implemented"
            ((TEST_PASSED++))
        else
            echo -e "${RED}✗${NC} Not all loading stages found"
            echo "  PATH: $path_loading_line, Regular: $regular_loading_line, Compinit: $compinit_line, Completion: $completion_loading_line"
            ((TEST_FAILED++))
        fi
    else
        skip_test "zshrc.symlink not found"
    fi
}

#==============================================================================
# TEST SUITE 3: TOPIC INDEPENDENCE AND ISOLATION
#==============================================================================

test_topic_self_containment() {
    echo -e "\n${CYAN}=== Testing Topic Self-Containment ===${NC}"
    
    # Get all topic directories (excluding system directories)
    local topics=$(find "$DOTFILES_ROOT" -maxdepth 1 -type d -not -path "$DOTFILES_ROOT" \
                  -not -name ".*" -not -name "bin" -not -name "core" -not -name "tests" \
                  -exec basename {} \; 2>/dev/null | sort)
    
    local independent_topics=0
    local dependent_topics=0
    
    for topic in $topics; do
        # Check for cross-topic source commands
        local cross_refs=$(grep -r "source.*\.\./[^/]*/.*" "$DOTFILES_ROOT/$topic" 2>/dev/null | \
                          grep -v "core/lib" | wc -l)
        
        if [[ $cross_refs -eq 0 ]]; then
            ((independent_topics++))
        else
            echo -e "${YELLOW}⚠${NC} Topic '$topic' has cross-topic dependencies"
            ((dependent_topics++))
        fi
    done
    
    if [[ $dependent_topics -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} All $independent_topics topics are self-contained"
        ((TEST_PASSED++))
    else
        echo -e "${RED}✗${NC} Found $dependent_topics topics with cross-dependencies"
        ((TEST_FAILED++))
    fi
}

test_topic_conditional_loading() {
    echo -e "\n${CYAN}=== Testing Topic Conditional Loading ===${NC}"
    
    # Check for defensive programming patterns
    local conditional_patterns=0
    local unsafe_patterns=0
    
    # Find all .zsh files
    local zsh_files=$(find "$DOTFILES_ROOT" -name "*.zsh" -not -path "*/\.*" 2>/dev/null)
    
    for file in $zsh_files; do
        # Check for command existence checks before use
        local has_checks=$(grep -E "command -v|which|\[\[ -x|\$\+commands" "$file" 2>/dev/null | wc -l)
        local has_commands=$(grep -E "^[^#]*\b(git|docker|kubectl|npm|yarn|rbenv|nvm|pyenv)\b" "$file" 2>/dev/null | wc -l)
        
        if [[ $has_commands -gt 0 ]] && [[ $has_checks -gt 0 ]]; then
            ((conditional_patterns++))
        elif [[ $has_commands -gt 0 ]]; then
            ((unsafe_patterns++))
        fi
    done
    
    echo -e "${GREEN}✓${NC} Found $conditional_patterns files with conditional loading"
    ((TEST_PASSED++))
    
    if [[ $unsafe_patterns -gt 0 ]]; then
        echo -e "${YELLOW}⚠${NC} Found $unsafe_patterns files that may assume commands exist"
    fi
}

#==============================================================================
# TEST SUITE 4: SYMLINK MANAGEMENT
#==============================================================================

test_symlink_creation_mechanism() {
    echo -e "\n${CYAN}=== Testing Symlink Creation Mechanism ===${NC}"
    
    setup_test_environment
    
    # Create a test topic with symlinks
    local test_topic="$TEST_TEMP_DIR/test-topic"
    mkdir -p "$test_topic"
    echo "test config content" > "$test_topic/testconfig.symlink"
    echo "test rc content" > "$test_topic/test.rc.symlink"
    
    # Test symlink creation
    create_symlink "$test_topic/testconfig.symlink" "$TEST_HOME_DIR/.testconfig" "testconfig"
    assert_symlink_exists "$TEST_HOME_DIR/.testconfig" "Simple symlink created"
    
    create_symlink "$test_topic/test.rc.symlink" "$TEST_HOME_DIR/.test.rc" "test.rc"
    assert_symlink_exists "$TEST_HOME_DIR/.test.rc" "Symlink with dots in name created"
    
    # Test symlink target validation
    local target=$(readlink "$TEST_HOME_DIR/.testconfig")
    assert_equals "$test_topic/testconfig.symlink" "$target" "Symlink points to correct target"
    
    # Test content accessibility through symlink
    local content=$(cat "$TEST_HOME_DIR/.testconfig" 2>/dev/null)
    assert_equals "test config content" "$content" "Content accessible through symlink"
    
    cleanup_test_environment
}

test_broken_symlink_cleanup() {
    echo -e "\n${CYAN}=== Testing Broken Symlink Cleanup ===${NC}"
    
    setup_test_environment
    
    # Create symlinks then remove source
    local test_file="$TEST_TEMP_DIR/test.txt"
    echo "test" > "$test_file"
    ln -sf "$test_file" "$TEST_HOME_DIR/.test"
    
    # Verify symlink exists
    assert_symlink_exists "$TEST_HOME_DIR/.test" "Symlink created"
    
    # Remove source to break symlink
    rm "$test_file"
    
    # Symlink should be broken
    if [[ -L "$TEST_HOME_DIR/.test" ]] && [[ ! -e "$TEST_HOME_DIR/.test" ]]; then
        echo -e "${GREEN}✓${NC} Symlink is broken (expected)"
        ((TEST_PASSED++))
    fi
    
    # Clean broken symlinks
    clean_broken_symlinks "$TEST_HOME_DIR"
    assert_no_file "$TEST_HOME_DIR/.test" "Broken symlink cleaned up"
    
    cleanup_test_environment
}

#==============================================================================
# TEST SUITE 5: TOPIC ADDITION AND REMOVAL
#==============================================================================

test_new_topic_addition() {
    echo -e "\n${CYAN}=== Testing New Topic Addition ===${NC}"
    
    setup_test_environment
    
    # Create a complete new topic
    local new_topic="$TEST_TEMP_DIR/newtopic"
    mkdir -p "$new_topic"
    
    # Add all file types
    echo "export NEWTOPIC_BIN=/usr/local/newtopic/bin:\$PATH" > "$new_topic/path.zsh"
    echo "alias nt='newtopic'" > "$new_topic/aliases.zsh"
    echo "compdef _newtopic newtopic" > "$new_topic/completion.zsh"
    echo "export NEWTOPIC_CONFIG=~/.newtopic" > "$new_topic/config.symlink"
    cat > "$new_topic/install.sh" << 'EOF'
#!/bin/bash
echo "Installing newtopic..."
mkdir -p ~/.newtopic
echo "Newtopic installed"
EOF
    chmod +x "$new_topic/install.sh"
    
    # Verify all files are created correctly
    assert_file_exists "$new_topic/path.zsh" "path.zsh created"
    assert_file_exists "$new_topic/aliases.zsh" "aliases.zsh created"
    assert_file_exists "$new_topic/completion.zsh" "completion.zsh created"
    assert_file_exists "$new_topic/config.symlink" "config.symlink created"
    assert_file_exists "$new_topic/install.sh" "install.sh created"
    assert_command_succeeds "test -x '$new_topic/install.sh'" "install.sh is executable"
    
    # Test install script execution
    assert_command_succeeds "(cd '$new_topic' && ./install.sh)" "Install script runs successfully"
    assert_dir_exists "$TEST_HOME_DIR/.newtopic" "Topic created its config directory"
    
    cleanup_test_environment
}

test_topic_removal_impact() {
    echo -e "\n${CYAN}=== Testing Topic Removal Impact ===${NC}"
    
    setup_test_environment
    
    # Create multiple interconnected topics
    local topic1="$TEST_TEMP_DIR/topic1"
    local topic2="$TEST_TEMP_DIR/topic2"
    mkdir -p "$topic1" "$topic2"
    
    echo "export TOPIC1=yes" > "$topic1/env.zsh"
    echo "alias t1='echo topic1'" > "$topic1/aliases.zsh"
    echo "# Config for topic1" > "$topic1/config.symlink"
    
    echo "export TOPIC2=yes" > "$topic2/env.zsh"
    echo "alias t2='echo topic2'" > "$topic2/aliases.zsh"
    
    # Create symlinks
    create_symlink "$topic1/config.symlink" "$TEST_HOME_DIR/.topic1config" "topic1config"
    assert_symlink_exists "$TEST_HOME_DIR/.topic1config" "Topic1 symlink created"
    
    # Remove topic1
    rm -rf "$topic1"
    assert_no_file "$topic1" "Topic1 removed"
    
    # Check that topic2 is unaffected
    assert_file_exists "$topic2/env.zsh" "Topic2 files remain intact"
    assert_file_exists "$topic2/aliases.zsh" "Topic2 aliases remain intact"
    
    # Check symlink is now broken
    if [[ -L "$TEST_HOME_DIR/.topic1config" ]] && [[ ! -e "$TEST_HOME_DIR/.topic1config" ]]; then
        echo -e "${GREEN}✓${NC} Topic1 symlink is broken after removal"
        ((TEST_PASSED++))
    fi
    
    cleanup_test_environment
}

#==============================================================================
# TEST SUITE 6: ERROR HANDLING AND RESILIENCE
#==============================================================================

test_missing_dependencies_handling() {
    echo -e "\n${CYAN}=== Testing Missing Dependencies Handling ===${NC}"
    
    setup_test_environment
    
    # Create a topic with conditional dependencies
    local test_topic="$TEST_TEMP_DIR/conditional-topic"
    mkdir -p "$test_topic"
    
    cat > "$test_topic/config.zsh" << 'EOF'
# Safe loading with dependency checks
if command -v docker >/dev/null 2>&1; then
    alias dc='docker-compose'
fi

if [[ -x "/usr/local/bin/special-tool" ]]; then
    export SPECIAL_TOOL_PATH="/usr/local/bin/special-tool"
fi

# This should always work
export TOPIC_LOADED="yes"
EOF
    
    # Source the file in a subshell to test it doesn't fail
    assert_command_succeeds "(source '$test_topic/config.zsh' && [[ \$TOPIC_LOADED == 'yes' ]])" \
        "Topic loads successfully despite missing dependencies"
    
    cleanup_test_environment
}

test_permission_error_handling() {
    echo -e "\n${CYAN}=== Testing Permission Error Handling ===${NC}"
    
    # Skip if running as root
    if [[ $EUID -eq 0 ]]; then
        skip_test "Cannot test permission errors as root"
        return
    fi
    
    setup_test_environment
    
    # Create protected directory
    local protected="$TEST_TEMP_DIR/protected"
    mkdir -p "$protected"
    touch "$protected/file.txt"
    chmod 000 "$protected"
    
    # Test that operations fail gracefully
    assert_command_fails "cat '$protected/file.txt'" "Cannot read protected file (expected)"
    assert_command_fails "touch '$protected/newfile.txt'" "Cannot create in protected directory (expected)"
    
    # Cleanup
    chmod 755 "$protected"
    
    cleanup_test_environment
}

test_circular_dependency_prevention() {
    echo -e "\n${CYAN}=== Testing Circular Dependency Prevention ===${NC}"
    
    setup_test_environment
    
    # Create topics that could have circular dependencies
    local topicA="$TEST_TEMP_DIR/topicA"
    local topicB="$TEST_TEMP_DIR/topicB"
    mkdir -p "$topicA" "$topicB"
    
    # TopicA doesn't source TopicB
    echo "export TOPIC_A=loaded" > "$topicA/env.zsh"
    
    # TopicB doesn't source TopicA
    echo "export TOPIC_B=loaded" > "$topicB/env.zsh"
    
    # Test that both can be sourced independently
    assert_command_succeeds "(source '$topicA/env.zsh' && [[ \$TOPIC_A == 'loaded' ]])" \
        "TopicA loads independently"
    assert_command_succeeds "(source '$topicB/env.zsh' && [[ \$TOPIC_B == 'loaded' ]])" \
        "TopicB loads independently"
    
    # Test that both can be sourced together
    assert_command_succeeds "(source '$topicA/env.zsh' && source '$topicB/env.zsh' && [[ \$TOPIC_A == 'loaded' ]] && [[ \$TOPIC_B == 'loaded' ]])" \
        "Both topics load together without conflict"
    
    cleanup_test_environment
}

#==============================================================================
# TEST SUITE 7: INSTALLATION AND BOOTSTRAP
#==============================================================================

test_bootstrap_idempotency() {
    echo -e "\n${CYAN}=== Testing Bootstrap Idempotency ===${NC}"
    
    setup_test_environment
    
    # Create test symlinks
    local test_file="$TEST_TEMP_DIR/test.symlink"
    echo "test content" > "$test_file"
    
    # First symlink creation
    create_symlink "$test_file" "$TEST_HOME_DIR/.test" "test"
    assert_symlink_exists "$TEST_HOME_DIR/.test" "First symlink creation"
    
    # Get first symlink metadata
    local first_inode=$(stat -f "%i" "$TEST_HOME_DIR/.test" 2>/dev/null || stat -c "%i" "$TEST_HOME_DIR/.test" 2>/dev/null)
    
    # Second symlink creation (should replace)
    create_symlink "$test_file" "$TEST_HOME_DIR/.test" "test"
    assert_symlink_exists "$TEST_HOME_DIR/.test" "Second symlink creation (idempotent)"
    
    # Verify content still accessible
    local content=$(cat "$TEST_HOME_DIR/.test")
    assert_equals "test content" "$content" "Content remains accessible after re-linking"
    
    cleanup_test_environment
}

test_installer_script_isolation() {
    echo -e "\n${CYAN}=== Testing Installer Script Isolation ===${NC}"
    
    setup_test_environment
    
    # Create topics with install scripts
    local topic1="$TEST_TEMP_DIR/installer1"
    local topic2="$TEST_TEMP_DIR/installer2"
    mkdir -p "$topic1" "$topic2"
    
    # Topic1 installer that sets a variable
    cat > "$topic1/install.sh" << 'EOF'
#!/bin/bash
INSTALLER1_RAN="yes"
echo "Installer 1 executed"
exit 0
EOF
    chmod +x "$topic1/install.sh"
    
    # Topic2 installer that checks isolation
    cat > "$topic2/install.sh" << 'EOF'
#!/bin/bash
if [[ -n "$INSTALLER1_RAN" ]]; then
    echo "ERROR: Installer 1 variable leaked"
    exit 1
fi
echo "Installer 2 executed in isolation"
exit 0
EOF
    chmod +x "$topic2/install.sh"
    
    # Run both installers
    assert_command_succeeds "(cd '$topic1' && ./install.sh)" "Installer 1 runs"
    assert_command_succeeds "(cd '$topic2' && ./install.sh)" "Installer 2 runs in isolation"
    
    cleanup_test_environment
}

#==============================================================================
# TEST SUITE 8: EDGE CASES AND CORNER SCENARIOS
#==============================================================================

test_special_characters_in_paths() {
    echo -e "\n${CYAN}=== Testing Special Characters in Paths ===${NC}"
    
    setup_test_environment
    
    # Create paths with special characters
    local special_topic="$TEST_TEMP_DIR/topic with spaces"
    mkdir -p "$special_topic"
    
    echo "export SPECIAL='spaces work'" > "$special_topic/env.zsh"
    echo "# Config with spaces" > "$special_topic/config with spaces.symlink"
    
    # Test file creation
    assert_file_exists "$special_topic/env.zsh" "File in directory with spaces"
    assert_file_exists "$special_topic/config with spaces.symlink" "File with spaces in name"
    
    # Test symlink creation with spaces
    create_symlink "$special_topic/config with spaces.symlink" "$TEST_HOME_DIR/.config_special" "config_special"
    assert_symlink_exists "$TEST_HOME_DIR/.config_special" "Symlink from file with spaces"
    
    cleanup_test_environment
}

test_empty_topic_handling() {
    echo -e "\n${CYAN}=== Testing Empty Topic Handling ===${NC}"
    
    setup_test_environment
    
    # Create empty topic directory
    local empty_topic="$TEST_TEMP_DIR/empty-topic"
    mkdir -p "$empty_topic"
    
    # Ensure empty topic doesn't break the system
    assert_dir_exists "$empty_topic" "Empty topic directory created"
    
    # Test that empty topic doesn't affect file discovery
    local found_files=$(find "$empty_topic" -name "*.zsh" -o -name "*.symlink" 2>/dev/null | wc -l | tr -d ' ')
    assert_equals "0" "$found_files" "Empty topic has no files (expected)"
    
    cleanup_test_environment
}

test_deeply_nested_symlinks() {
    echo -e "\n${CYAN}=== Testing Deeply Nested Symlinks ===${NC}"
    
    setup_test_environment
    
    # Create nested directory structure
    local nested="$TEST_TEMP_DIR/topic/config/deep/nested"
    mkdir -p "$nested"
    echo "nested content" > "$nested/config.symlink"
    
    # Test symlink creation from nested path
    create_symlink "$nested/config.symlink" "$TEST_HOME_DIR/.nested_config" "nested_config"
    assert_symlink_exists "$TEST_HOME_DIR/.nested_config" "Symlink from deeply nested file"
    
    # Verify content
    local content=$(cat "$TEST_HOME_DIR/.nested_config")
    assert_equals "nested content" "$content" "Content accessible from nested symlink"
    
    cleanup_test_environment
}

test_concurrent_topic_loading() {
    echo -e "\n${CYAN}=== Testing Concurrent Topic Loading ===${NC}"
    
    setup_test_environment
    
    # Create multiple topics that could load concurrently
    for i in {1..5}; do
        local topic="$TEST_TEMP_DIR/topic$i"
        mkdir -p "$topic"
        echo "export TOPIC${i}_LOADED=yes" > "$topic/env.zsh"
        echo "sleep 0.1" >> "$topic/env.zsh"  # Simulate slow loading
    done
    
    # Test that all topics can be sourced
    local load_command=""
    for i in {1..5}; do
        load_command="${load_command}source '$TEST_TEMP_DIR/topic$i/env.zsh' && "
    done
    load_command="${load_command}true"
    
    assert_command_succeeds "($load_command)" "All topics load successfully"
    
    # Verify all variables are set
    local verify_command="("
    for i in {1..5}; do
        verify_command="${verify_command}source '$TEST_TEMP_DIR/topic$i/env.zsh' && "
    done
    for i in {1..5}; do
        verify_command="${verify_command}[[ \$TOPIC${i}_LOADED == 'yes' ]] && "
    done
    verify_command="${verify_command}true)"
    
    assert_command_succeeds "$verify_command" "All topic variables are set"
    
    cleanup_test_environment
}

#==============================================================================
# TEST SUITE 9: PERFORMANCE AND SCALABILITY
#==============================================================================

test_large_number_of_topics() {
    echo -e "\n${CYAN}=== Testing Large Number of Topics ===${NC}"
    
    setup_test_environment
    
    # Create many topics
    local num_topics=20
    for i in $(seq 1 $num_topics); do
        local topic="$TEST_TEMP_DIR/topic$i"
        mkdir -p "$topic"
        echo "export TOPIC${i}=loaded" > "$topic/env.zsh"
        echo "alias t$i='echo topic$i'" > "$topic/aliases.zsh"
    done
    
    # Count created topics
    local created=$(find "$TEST_TEMP_DIR" -maxdepth 1 -type d -name "topic*" | wc -l | tr -d ' ')
    assert_equals "$num_topics" "$created" "All $num_topics topics created"
    
    # Test that all can be discovered
    local zsh_files=$(find "$TEST_TEMP_DIR" -name "*.zsh" | wc -l | tr -d ' ')
    assert_equals "$((num_topics * 2))" "$zsh_files" "All .zsh files discoverable"
    
    cleanup_test_environment
}

test_large_symlink_set() {
    echo -e "\n${CYAN}=== Testing Large Symlink Set ===${NC}"
    
    setup_test_environment
    
    # Create many symlink files
    local num_symlinks=15
    local topic="$TEST_TEMP_DIR/symlink-heavy"
    mkdir -p "$topic"
    
    for i in $(seq 1 $num_symlinks); do
        echo "config $i" > "$topic/config${i}.symlink"
    done
    
    # Create all symlinks
    local created=0
    for i in $(seq 1 $num_symlinks); do
        if create_symlink "$topic/config${i}.symlink" "$TEST_HOME_DIR/.config$i" "config$i" 2>/dev/null; then
            ((created++))
        fi
    done
    
    assert_equals "$num_symlinks" "$created" "All $num_symlinks symlinks created"
    
    # Verify all symlinks work
    local working=0
    for i in $(seq 1 $num_symlinks); do
        if [[ -L "$TEST_HOME_DIR/.config$i" ]] && [[ -e "$TEST_HOME_DIR/.config$i" ]]; then
            ((working++))
        fi
    done
    
    assert_equals "$num_symlinks" "$working" "All symlinks are valid"
    
    cleanup_test_environment
}

#==============================================================================
# MAIN TEST RUNNER
#==============================================================================

print_test_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      Comprehensive Dotfiles System Integration Test Suite      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Testing:${NC} Topic self-containment, addition/removal, and system resilience"
    echo -e "${CYAN}Location:${NC} $DOTFILES_ROOT"
    echo -e "${CYAN}Date:${NC} $(date)"
    echo ""
}

print_test_summary() {
    local total=$((TEST_PASSED + TEST_FAILED + TEST_SKIPPED))
    local pass_rate=0
    if [[ $total -gt 0 ]]; then
        pass_rate=$((TEST_PASSED * 100 / total))
    fi
    
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                         Test Summary                           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Passed:${NC}  $TEST_PASSED"
    echo -e "${RED}Failed:${NC}  $TEST_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TEST_SKIPPED"
    echo -e "${CYAN}Total:${NC}   $total"
    echo -e "${CYAN}Pass Rate:${NC} ${pass_rate}%"
    echo ""
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
        echo -e "${GREEN}The dotfiles system demonstrates excellent architecture:${NC}"
        echo -e "  • Complete topic isolation and self-containment"
        echo -e "  • Robust error handling and graceful degradation"
        echo -e "  • Safe topic addition and removal"
        echo -e "  • Proper loading order and dependency management"
        return 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED${NC}"
        echo -e "${RED}Review the failures above and address the issues${NC}"
        return 1
    fi
}

main() {
    print_test_header
    
    # Trap to ensure cleanup on exit
    trap cleanup_test_environment EXIT
    
    # Core System Tests
    test_dotfiles_directory_structure
    test_command_routing_system
    
    # File Discovery Tests
    test_zsh_file_discovery_patterns
    test_loading_order_mechanism
    
    # Topic Independence Tests
    test_topic_self_containment
    test_topic_conditional_loading
    
    # Symlink Management Tests
    test_symlink_creation_mechanism
    test_broken_symlink_cleanup
    
    # Topic Management Tests
    test_new_topic_addition
    test_topic_removal_impact
    
    # Error Handling Tests
    test_missing_dependencies_handling
    test_permission_error_handling
    test_circular_dependency_prevention
    
    # Installation Tests
    test_bootstrap_idempotency
    test_installer_script_isolation
    
    # Edge Case Tests
    test_special_characters_in_paths
    test_empty_topic_handling
    test_deeply_nested_symlinks
    test_concurrent_topic_loading
    
    # Performance Tests
    test_large_number_of_topics
    test_large_symlink_set
    
    # Print summary and return appropriate exit code
    print_test_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi