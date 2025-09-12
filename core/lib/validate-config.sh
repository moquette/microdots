#!/usr/bin/env bash
# Configuration validation for dotfiles system
# Detects and warns about common configuration issues

set -euo pipefail

# Source the common library to get UI functions
VALIDATE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$VALIDATE_SCRIPT_DIR/common.sh"

# Validate dotfiles.conf for common issues
validate_dotfiles_conf() {
    local config_file="${1:-$HOME/.dotfiles/dotfiles.conf}"
    local errors=0
    local warnings=0
    
    if [[ ! -f "$config_file" ]]; then
        return 0  # No config file is valid
    fi
    
    # Check for multiple LOCAL_DOTS or DOTLOCAL definitions
    local path_count dotlocal_count
    path_count=$(grep "^LOCAL_DOTS=" "$config_file" 2>/dev/null | wc -l | tr -d ' ')
    dotlocal_count=$(grep "^DOTLOCAL=" "$config_file" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$path_count" -gt 1 ]] || [[ "$dotlocal_count" -gt 1 ]]; then
        error "Multiple LOCAL_DOTS/DOTLOCAL definitions found in dotfiles.conf"
        error "Found $path_count LOCAL_DOTS and $dotlocal_count DOTLOCAL definitions. Only one should be active."
        grep -n "^LOCAL_DOTS=\|^DOTLOCAL=" "$config_file" | while read -r line; do
            warning "  $line"
        done
        error "The last definition will take precedence, which may not be intended."
        errors=1
    fi
    
    # Check if both OLD and NEW variables are defined
    if [[ "$path_count" -gt 0 ]] && [[ "$dotlocal_count" -gt 0 ]]; then
        warning "Both LOCAL_DOTS and DOTLOCAL are defined"
        warning "DOTLOCAL will take precedence. Consider removing LOCAL_DOTS."
        warnings=1
    fi
    
    # Check for uncommented example commands
    if grep -q "^ln -s" "$config_file" 2>/dev/null; then
        error "Uncommented 'ln -s' command found in dotfiles.conf"
        error "This will execute every time the config is sourced."
        grep -n "^ln -s" "$config_file" | while read -r line; do
            warning "  $line"
        done
        error "Comment out or remove these lines."
        errors=1
    fi
    
    # Check if DOTLOCAL/LOCAL_DOTS and symlink creation are both active
    if [[ "$path_count" -gt 0 || "$dotlocal_count" -gt 0 ]] && grep -q "^ln -s.*local" "$config_file" 2>/dev/null; then
        warning "Both DOTLOCAL/LOCAL_DOTS and symlink creation are active"
        echo -e "${YELLOW}         This may cause conflicts. Use only one method.${NC}" >&2
        warnings=1
    fi
    
    # Check if DOTLOCAL/LOCAL_DOTS points to a non-existent directory
    if [[ "$path_count" -eq 1 ]] || [[ "$dotlocal_count" -eq 1 ]]; then
        local configured_path
        configured_path=$(source "$config_file" 2>/dev/null && echo "${DOTLOCAL:-${LOCAL_DOTS:-}}" || true)
        if [[ -n "$configured_path" ]]; then
            # Expand tilde in path using common function
            local expanded_path=$(expand_path "$configured_path")
            if [[ ! -d "$expanded_path" ]]; then
                warning "DOTLOCAL/LOCAL_DOTS points to non-existent directory:"
                echo -e "${YELLOW}         $configured_path${NC}" >&2
                echo -e "${YELLOW}         Create this directory or update the configuration.${NC}" >&2
                warnings=1
            fi
        fi
    fi
    
    # Check for multiple backup paths
    local backup_count
    backup_count=$(grep "^BACKUP_PATH=" "$config_file" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$backup_count" -gt 1 ]]; then
        warning "Multiple BACKUP_PATH definitions found"
        echo -e "${YELLOW}         Only the last one will be used.${NC}" >&2
        warnings=1
    fi
    
    return $errors
}

# Check for symlink conflicts
check_symlink_conflicts() {
    local local_dir="$HOME/.dotfiles/.local"
    
    # Check if both symlink and directory exist
    if [[ -L "$local_dir" ]] && [[ -d "$local_dir/.dotlocal" ]]; then
        warning "Symlink conflict detected"
        echo -e "${YELLOW}         ~/.dotfiles/.local is a symlink but contains .dotlocal${NC}" >&2
        echo -e "${YELLOW}         This may cause circular references.${NC}" >&2
        # This is a warning, not a blocking error
        return 0
    fi
    
    return 0
}

# Main validation function
validate_configuration() {
    local has_errors=0
    local has_warnings=0
    
    echo "Validating dotfiles configuration..." >&2
    
    # Validate dotfiles.conf (this returns errors via return code)
    if ! validate_dotfiles_conf; then
        has_errors=1
    fi
    
    # Check for symlink conflicts (this only shows warnings)
    check_symlink_conflicts
    
    if [[ "$has_errors" -eq 0 ]]; then
        success "Configuration is valid"
        return 0
    else
        error "Configuration has blocking errors that must be fixed"
        return 1
    fi
}

# Run validation if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    validate_configuration
fi