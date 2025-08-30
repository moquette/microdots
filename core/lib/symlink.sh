#!/usr/bin/env bash
# CRITICAL: Symlink precedence management for the dotlocal system
# Ensures local configurations ALWAYS override public ones

set -euo pipefail
IFS=$'\n\t'

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Check if file should be excluded from symlinking
should_exclude() {
    local source="$1"
    
    # Skip backup directories
    [[ "$source" == *"/vscode-backup/"* ]] && return 0
    [[ "$source" == *"/backups/"* ]] && return 0
    
    # Skip .git directory
    [[ "$source" == *"/.git/"* ]] && return 0
    
    # Skip example files
    [[ "$source" == *".example" ]] && return 0
    
    # Skip test files
    [[ "$source" == *"/tests/"* ]] && return 0
    
    return 1
}

# Get target path for a symlink source
get_symlink_target() {
    local source="$1"
    local filename=$(basename "$source")
    local base="${filename%.symlink}"
    
    # Add dot prefix unless already present
    if [[ "$base" = .* ]]; then
        echo "$HOME/$base"
    else
        echo "$HOME/.$base"
    fi
}

# Create symlink with proper handling
create_symlink_with_precedence() {
    local source="$1"
    local target="$2"
    local is_dry_run="${3:-false}"
    local force="${4:-false}"
    
    if [[ "$is_dry_run" == "true" ]]; then
        info "[dry-run] Would link $target → $source"
        return 0
    fi
    
    # If force mode or target doesn't exist, create it
    if [[ "$force" == "true" ]] || [[ ! -e "$target" && ! -L "$target" ]]; then
        # Remove existing to ensure clean replacement
        if [[ -e "$target" || -L "$target" ]]; then
            rm -rf "$target"
        fi
        
        # Create parent directory if needed
        local parent_dir=$(dirname "$target")
        [[ ! -d "$parent_dir" ]] && mkdir -p "$parent_dir"
        
        if ln -s "$source" "$target"; then
            success "Linked: $(basename "$target") → $(basename "$(dirname "$source")")/$(basename "$source")"
            return 0
        else
            error "Failed to link: $target"
            return 1
        fi
    else
        # Target exists and not in force mode - handle interactively
        return 2  # Signal that interactive handling is needed
    fi
}

# CRITICAL FUNCTION: Two-phase symlink creation with precedence
create_all_symlinks_with_precedence() {
    local dotfiles_dir="${1:-$HOME/.dotfiles}"
    local local_dir="${2:-}"  # No fallback - must be explicitly passed
    local is_dry_run="${3:-false}"
    local force="${4:-false}"
    
    local public_count=0
    local local_count=0
    local skip_count=0
    
    # PHASE 1: Process public configs FIRST
    if [[ "$is_dry_run" == "false" ]]; then
        info "Processing public configurations..."
    else
        info "Processing public configurations (dry-run)..."
    fi
    
    if [[ -d "$dotfiles_dir" ]]; then
        while IFS= read -r source; do
            should_exclude "$source" && continue
            
            local target=$(get_symlink_target "$source")
            
            # Skip if local version exists (will be handled in phase 2)
            if [[ -n "$local_dir" ]] && [[ -d "$local_dir" ]]; then
                local relative_path="${source#$dotfiles_dir/}"
                local local_equivalent="$local_dir/${relative_path}"
                if [[ -f "$local_equivalent" ]]; then
                    skip_count=$((skip_count + 1))
                    continue
                fi
            fi
            
            if create_symlink_with_precedence "$source" "$target" "$is_dry_run" "$force"; then
                public_count=$((public_count + 1))
            fi
        done < <(find "$dotfiles_dir" -name "*.symlink" -not -path "*/.local/*" -not -path "*/.dotlocal/*" 2>/dev/null)
    fi
    
    # PHASE 2: Process local configs SECOND (they override)
    if [[ -n "$local_dir" ]] && [[ -d "$local_dir" ]]; then
        if [[ "$is_dry_run" == "false" ]]; then
            info "Processing local overrides..."
        else
            info "Processing local overrides (dry-run)..."
        fi
        
        while IFS= read -r source; do
            should_exclude "$source" && continue
            
            local target=$(get_symlink_target "$source")
            # Force mode for local - they always override
            if create_symlink_with_precedence "$source" "$target" "$is_dry_run" "true"; then
                local_count=$((local_count + 1))
            fi
        done < <(find "$local_dir" -name "*.symlink" 2>/dev/null)
    else
        if [[ "$is_dry_run" == "false" ]]; then
            info "No local folder found - using public configs only"
        fi
    fi
    
    # Report results
    echo ""
    if [[ "$is_dry_run" == "false" ]]; then
        success "Symlink creation complete!"
        info "  Public configs: $public_count"
        info "  Local overrides: $local_count"
        if [[ $skip_count -gt 0 ]]; then
            info "  Skipped (have local): $skip_count"
        fi
    else
        info "Dry-run complete. Would create:"
        info "  Public configs: $public_count"
        info "  Local overrides: $local_count"
        if [[ $skip_count -gt 0 ]]; then
            info "  Skipped (have local): $skip_count"
        fi
    fi
}

# Clean broken symlinks in home directory
clean_broken_dotfile_symlinks() {
    local is_dry_run="${1:-false}"
    
    info "Cleaning broken symlinks in home directory..."
    local broken_count=0
    
    while IFS= read -r symlink; do
        if [[ ! -e "$symlink" ]]; then
            if [[ "$is_dry_run" == "true" ]]; then
                info "[dry-run] Would remove broken symlink: $symlink"
            else
                rm "$symlink"
                success "Removed broken symlink: $(basename "$symlink")"
            fi
            broken_count=$((broken_count + 1))
        fi
    done < <(find "$HOME" -maxdepth 1 -type l -name ".*" 2>/dev/null)
    
    if [[ $broken_count -gt 0 ]]; then
        info "Cleaned $broken_count broken symlinks"
    else
        info "No broken symlinks found"
    fi
}

# List all managed symlinks
list_managed_symlinks() {
    local dotfiles_dir="${1:-$HOME/.dotfiles}"
    local local_dir="${2:-}"  # No fallback - must be explicitly passed
    
    subheader "Managed Symlinks"
    blank
    
    # Find all symlinks pointing to dotfiles or local
    while IFS= read -r symlink; do
        if [[ -L "$symlink" ]]; then
            local target=$(readlink "$symlink")
            if [[ "$target" == *"$dotfiles_dir"* ]] || [[ -n "$local_dir" && "$target" == *"$local_dir"* ]]; then
                local source="Public"
                [[ -n "$local_dir" && "$target" == *"$local_dir"* ]] && source="LOCAL"
                printf "%-20s → %-50s [%s]\n" "$(basename "$symlink")" "$target" "$source"
            fi
        fi
    done < <(find "$HOME" -maxdepth 1 -name ".*" 2>/dev/null | sort)
}