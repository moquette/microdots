#!/usr/bin/env bash
# =============================================================================
# SYMLINK.SH - Single Source of Truth for Symlink Creation
# =============================================================================
#
# This library implements a three-tier architecture for all symlink creation
# in the dotfiles system, ensuring consistency, reliability, and maintainability.
#
# ⚠️  CRITICAL ARCHITECTURAL RULE ⚠️
# ONLY _create_symlink_raw() may call 'ln -s' directly.
# ALL other symlink creation MUST go through this library.
#
# =============================================================================
# THREE-TIER ARCHITECTURE:
# =============================================================================
#
# Layer 1: High-Level Orchestration Functions
# ├── create_all_symlinks_with_precedence()    # Main entry point with precedence
# ├── create_symlink_with_precedence()         # Individual symlinks with precedence
# └── create_subdirectory_symlinks()           # Directory pattern support
#
# Layer 2: Specialized Domain Functions
# ├── create_infrastructure_symlink()          # Dotlocal infrastructure symlinks
# ├── create_bootstrap_symlink()               # Bootstrap setup (minimal)
# ├── create_application_symlink()             # Application configs (Claude Desktop)
# └── create_command_symlink()                 # Command line tools (bin/dots)
#
# Layer 3: Low-Level Implementation (SINGLE SOURCE OF TRUTH)
# └── _create_symlink_raw()                    # ONLY function allowed to call ln -s
#
# =============================================================================
# KEY BENEFITS:
# =============================================================================
#
# 1. Single Source of Truth: All symlink creation goes through one validated path
# 2. Consistent Behavior: Same error handling and logging across all use cases
# 3. Command Substitution Safety: All functions separate debug output (stderr) from return values (stdout)
# 4. Easy Maintenance: Bug fixes in one place benefit all symlink operations
# 5. Specialized Optimization: Each Layer 2 function optimized for its domain
# 6. Dotlocal Precedence: Ensures local configurations always override public ones
#
# =============================================================================
# USAGE EXAMPLES:
# =============================================================================
#
# For dotlocal infrastructure symlinks:
# create_infrastructure_symlink "$HOME/.dotfiles/core" "$HOME/.dotlocal/core" "core" "false" "true"
#
# For bootstrap setup:
# create_bootstrap_symlink "$source" "$target" "$name" "false"
#
# For application configurations:
# create_application_symlink "$source" "$target" "$app_name" "false" "false" "true"
#
# For command line tools:
# create_command_symlink "$source" "$target" "$command_name" "false"
#
# =============================================================================
# MIGRATION GUIDE:
# =============================================================================
#
# NEVER DO THIS (violates single source of truth):
# ln -s "$source" "$target"                    # FORBIDDEN
# command ln -s "$source" "$target"            # FORBIDDEN
#
# ALWAYS DO THIS (use appropriate specialized function):
# create_infrastructure_symlink "$source" "$target" "$name" "false" "true"
#
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Default UI callback function - can be overridden by commands
symlink_ui_callback() {
    local event="$1"
    local message="$2"

    case "$event" in
        "progress")
            info "$message"
            ;;
        "success")
            success "$message"
            ;;
        "error")
            error "$message"
            ;;
        "skip")
            # Default: don't show skips unless verbose
            ;;
        "link")
            success "$message"
            ;;
        *)
            info "$message"
            ;;
    esac
}

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

# Check if a .symlink directory should use subdirectory pattern
should_use_subdirectory_pattern() {
    local source="$1"

    # If it's a directory and contains subdirectories, use subdirectory pattern
    if [[ -d "$source" ]]; then
        # Check if it has subdirectories (not just files)
        local subdir_count=$(find "$source" -mindepth 1 -maxdepth 1 -type d | wc -l)
        if [[ $subdir_count -gt 0 ]]; then
            return 0  # true - use subdirectory pattern
        fi
    fi
    return 1  # false - use normal pattern
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

# Create subdirectory symlinks for .symlink directories with subdirs
create_subdirectory_symlinks() {
    local source_dir="$1"
    local target_base="$2"
    local is_dry_run="${3:-false}"
    local force="${4:-false}"
    local count=0

    # Create parent directory if it doesn't exist
    if [[ "$is_dry_run" == "false" ]] && [[ ! -d "$target_base" ]]; then
        mkdir -p "$target_base"
    fi

    # Process each subdirectory
    for subdir in "$source_dir"/*; do
        if [[ -d "$subdir" ]]; then
            local subdir_name=$(basename "$subdir")
            local target="$target_base/$subdir_name"

            if [[ "$is_dry_run" == "true" ]]; then
                echo "[dry-run] Would link $target → $subdir" >&2  # Send to stderr to avoid contaminating command substitution
                count=$((count + 1))
            else
                # If force mode or target doesn't exist, create it
                if [[ "$force" == "true" ]] || [[ ! -e "$target" && ! -L "$target" ]]; then
                    # Remove existing to ensure clean replacement
                    if [[ -e "$target" || -L "$target" ]]; then
                        rm -rf "$target"
                    fi

                    if _create_symlink_raw "$subdir" "$target" "$force" "false"; then
                        # Only report individual links in verbose mode via callback
                        if [[ "${SYMLINK_VERBOSE:-false}" == "true" ]]; then
                            local display_msg="$subdir_name → $(basename "$(dirname "$subdir")")/$(basename "$subdir")"
                            symlink_ui_callback "skip" "$display_msg"
                        fi
                        count=$((count + 1))
                    else
                        symlink_ui_callback "error" "Failed to link: $target"
                    fi
                fi
            fi
        fi
    done

    echo $count  # Return count via stdout, not exit code
    return 0      # Always return success
}

# Create symlink with proper handling
create_symlink_with_precedence() {
    local source="$1"
    local target="$2"
    local is_dry_run="${3:-false}"
    local force="${4:-false}"

    if [[ "$is_dry_run" == "true" ]]; then
        echo "[dry-run] Would link $target → $source" >&2  # Send to stderr to avoid contaminating command substitution
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

        if _create_symlink_raw "$source" "$target" "$force" "false"; then
            # Only report individual links in verbose mode via callback
            if [[ "${SYMLINK_VERBOSE:-false}" == "true" ]]; then
                local display_msg="$(basename "$target") → $(basename "$(dirname "$source")")/$(basename "$source")"
                symlink_ui_callback "skip" "$display_msg"  # Use skip for individual items
            fi
            return 0
        else
            symlink_ui_callback "error" "Failed to link: $target"
            return 1
        fi
    else
        # Target exists and not in force mode - handle interactively
        return 2  # Signal that interactive handling is needed
    fi
}

# UI Callback interface for command integration
# Commands can provide callbacks for progress reporting
symlink_ui_callback() {
    local action="$1"
    local message="${2:-}"
    local details="${3:-}"

    # Default implementation (can be overridden by sourcing command)
    case "$action" in
        "subheader") subheader "$message" ;;
        "progress") progress "$message" ;;
        "success") success "$message" ;;
        "info") info "$message" ;;
        "skip") [[ "${SYMLINK_VERBOSE:-false}" == "true" ]] && indent "$message" ;;
        "count") ;; # Default: no-op for count updates
    esac
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
    symlink_ui_callback "subheader" "Symlink Creation"
    if [[ "$is_dry_run" == "false" ]]; then
        symlink_ui_callback "progress" "Processing public configurations"
    else
        symlink_ui_callback "info" "Processing public configurations (dry-run)"
    fi
    
    if [[ -d "$dotfiles_dir" ]]; then
        while IFS= read -r source; do
            should_exclude "$source" && continue

            # Check if this should use subdirectory pattern
            if should_use_subdirectory_pattern "$source"; then
                local target_base=$(get_symlink_target "$source")

                # Skip if local version exists (will be handled in phase 2)
                if [[ -n "$local_dir" ]] && [[ -d "$local_dir" ]]; then
                    local relative_path="${source#$dotfiles_dir/}"
                    local local_equivalent="$local_dir/${relative_path}"
                    if [[ -e "$local_equivalent" ]]; then
                        skip_count=$((skip_count + 1))
                        continue
                    fi
                fi

                # Use subdirectory symlink pattern
                local linked_count=0
                linked_count=$(create_subdirectory_symlinks "$source" "$target_base" "$is_dry_run" "$force")
                public_count=$((public_count + linked_count))
            else
                # Use normal symlink pattern
                local target=$(get_symlink_target "$source")

                # Skip if local version exists (will be handled in phase 2)
                if [[ -n "$local_dir" ]] && [[ -d "$local_dir" ]]; then
                    local relative_path="${source#$dotfiles_dir/}"
                    local local_equivalent="$local_dir/${relative_path}"
                    if [[ -e "$local_equivalent" ]]; then
                        skip_count=$((skip_count + 1))
                        symlink_ui_callback "skip" "Skipped $(basename "$target") (has local override)"
                        continue
                    fi
                fi

                if create_symlink_with_precedence "$source" "$target" "$is_dry_run" "$force"; then
                    public_count=$((public_count + 1))
                    symlink_ui_callback "count" "public" "$public_count"
                fi
            fi
        done < <(find "$dotfiles_dir" -name "*.symlink" -not -path "*/.local/*" -not -path "*/.dotlocal/*" 2>/dev/null)
    fi
    
    symlink_ui_callback "success" "Public configurations linked: $public_count"

    # PHASE 2: Process local configs SECOND (they override)
    if [[ -n "$local_dir" ]] && [[ -d "$local_dir" ]]; then
        if [[ "$is_dry_run" == "false" ]]; then
            symlink_ui_callback "progress" "Processing local overrides"
        else
            symlink_ui_callback "info" "Processing local overrides (dry-run)"
        fi
        
        while IFS= read -r source; do
            should_exclude "$source" && continue

            # Check if this should use subdirectory pattern
            if should_use_subdirectory_pattern "$source"; then
                local target_base=$(get_symlink_target "$source")
                # Use subdirectory symlink pattern with force for local overrides
                local linked_count=0
                linked_count=$(create_subdirectory_symlinks "$source" "$target_base" "$is_dry_run" "true")
                local_count=$((local_count + linked_count))
            else
                # Use normal symlink pattern
                local target=$(get_symlink_target "$source")
                # Force mode for local - they always override
                if create_symlink_with_precedence "$source" "$target" "$is_dry_run" "true"; then
                    local_count=$((local_count + 1))
                    symlink_ui_callback "count" "local" "$local_count"
                fi
            fi
        done < <(find "$local_dir" -name "*.symlink" 2>/dev/null)

        symlink_ui_callback "success" "Local overrides linked: $local_count"
    else
        if [[ "$is_dry_run" == "false" ]]; then
            symlink_ui_callback "info" "No local directory available for overrides"
        fi
    fi

    # Return counts for caller to use (avoid duplicate reporting)
    # Caller can access via global variables or return array
    SYMLINK_PUBLIC_COUNT=$public_count
    SYMLINK_LOCAL_COUNT=$local_count
    SYMLINK_SKIP_COUNT=$skip_count

    return 0  # Success
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

# Low-level symlink creation with comprehensive error handling
# Used internally by all higher-level functions
_create_symlink_raw() {
    local source="$1"
    local target="$2"
    local force="${3:-false}"
    local allow_existing="${4:-false}"

    # Parameter validation
    [[ -z "$source" ]] && { echo "Error: Source path required" >&2; return 1; }
    [[ -z "$target" ]] && { echo "Error: Target path required" >&2; return 1; }
    [[ ! -e "$source" ]] && { echo "Error: Source does not exist: $source" >&2; return 1; }

    # Handle existing target
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ "$force" == "true" ]]; then
            rm -rf "$target"
        elif [[ "$allow_existing" == "false" ]]; then
            return 2  # Signal that target exists
        fi
    fi

    # Use the low-level function for actual symlink creation
    if _create_symlink_raw "$source" "$target" "$force" "false"; then
        # Only report individual links in verbose mode via callback
        if [[ "${SYMLINK_VERBOSE:-false}" == "true" ]]; then
            local display_msg="$(basename "$target") → $(basename "$(dirname "$source")")/$(basename "$source")"
            symlink_ui_callback "skip" "$display_msg"  # Use skip for individual items
        fi
        return 0
    else
        symlink_ui_callback "error" "Failed to link: $target"
        return 1
    fi
}

# (Removed duplicate create_infrastructure_symlink - using the one in Layer 2 below)

# Create bootstrap symlink (minimal for early setup)
create_bootstrap_symlink() {
    local source="$1"
    local target="$2"
    local name="${3:-$(basename "$target")}"
    local skip_existing="${4:-false}"

    # Check if we should skip
    if [[ "$skip_existing" == "true" && (-e "$target" || -L "$target") ]]; then
        return 0  # Skip existing
    fi

    if _create_symlink_raw "$source" "$target" "true" "false"; then
        echo "✓ Linked $name"
        return 0
    else
        echo "✗ Failed to link $name" >&2
        return 1
    fi
}

# Create application-specific symlink (for Claude Desktop, etc.)
create_application_symlink() {
    local source="$1"
    local target="$2"
    local name="${3:-$(basename "$target")}"
    local force="${4:-false}"
    local dry_run="${5:-false}"
    local verbose="${6:-false}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] Would link $target → $source"
        return 0
    fi

    # Check if update is needed
    local update_needed=false
    if [[ ! -e "$target" ]]; then
        update_needed=true
    elif [[ -L "$target" ]]; then
        local current_target=$(readlink "$target")
        if [[ "$current_target" != "$source" ]]; then
            update_needed=true
        fi
    elif [[ "$force" == "true" ]]; then
        update_needed=true
    elif [[ -e "$target" ]]; then
        [[ "$verbose" == "true" ]] && echo "⚠ Regular file exists, skipping: $name"
        return 2  # Exists but not a symlink
    fi

    if [[ "$update_needed" == "true" ]]; then
        if _create_symlink_raw "$source" "$target" "true" "false"; then
            [[ "$verbose" == "true" ]] && echo "✓ Application symlink created: $name"
            return 0
        else
            echo "✗ Failed to link application file: $name" >&2
            return 1
        fi
    else
        [[ "$verbose" == "true" ]] && echo "› Application symlink already correct: $name"
        return 0  # Already correct
    fi
}

# Create command symlink (for bin/ commands)
create_command_symlink() {
    local source="$1"
    local target="$2"
    local name="${3:-$(basename "$target")}"

    if [[ ! -L "$target" ]]; then
        if _create_symlink_raw "$source" "$target" "true" "false"; then
            echo "✓ Created $name command symlink"
            return 0
        else
            echo "✗ Failed to create $name command symlink" >&2
            return 1
        fi
    else
        return 0  # Already exists
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

# ==============================================================================
# THREE-TIER SYMLINK ARCHITECTURE
# ==============================================================================
# Layer 1: High-level functions (above)
# Layer 2: Specialized functions (below)
# Layer 3: Low-level implementation (bottom)
# ==============================================================================

# Layer 2: Specialized symlink creation functions

# Create infrastructure symlinks (for paths.sh)
create_infrastructure_symlink() {
    local source="$1"
    local target="$2"
    local name="${3:-$(basename "$target")}"
    local force="${4:-false}"
    local verbose="${5:-false}"

    [[ "$verbose" == "true" ]] && info "Creating infrastructure symlink: $name" >&2

    if _create_symlink_raw "$source" "$target" "$force" "true"; then
        [[ "$verbose" == "true" ]] && success "Infrastructure symlink created: $name → $source" >&2
        return 0
    else
        error "Failed to create infrastructure symlink: $name" >&2
        return 1
    fi
}

# Create bootstrap symlinks (minimal for early setup)
create_bootstrap_symlink() {
    local source="$1"
    local target="$2"
    local name="${3:-$(basename "$target")}"
    local skip_existing="${4:-false}"

    # Bootstrap-specific: skip if exists
    if [[ "$skip_existing" == "true" ]] && [[ -e "$target" ]]; then
        return 0
    fi

    if _create_symlink_raw "$source" "$target" "true" "false"; then
        success "Linked: $name"
        return 0
    else
        error "Failed to link: $name"
        return 1
    fi
}

# Create application-specific symlinks (Claude Desktop, MCP)
create_application_symlink() {
    local source="$1"
    local target="$2"
    local app_name="${3:-application}"
    local force="${4:-false}"
    local dry_run="${5:-false}"
    local verbose="${6:-false}"

    if [[ "$dry_run" == "true" ]]; then
        [[ "$verbose" == "true" ]] && info "[dry-run] Would link $app_name: $target → $source" >&2
        return 0
    fi

    # Check if update needed
    local update_needed="false"
    if [[ ! -e "$target" ]]; then
        update_needed="true"
    elif [[ -L "$target" ]]; then
        local current_target=$(readlink "$target")
        [[ "$current_target" != "$source" ]] && update_needed="true"
    elif [[ "$force" == "true" ]]; then
        update_needed="true"
    fi

    if [[ "$update_needed" == "true" ]]; then
        if _create_symlink_raw "$source" "$target" "$force" "false"; then
            [[ "$verbose" == "true" ]] && success "$app_name symlink updated" >&2
            return 0
        else
            error "Failed to create $app_name symlink" >&2
            return 1
        fi
    else
        [[ "$verbose" == "true" ]] && info "$app_name symlink already correct" >&2
        return 0
    fi
}

# Create command symlinks (for bin/dots)
create_command_symlink() {
    local source="$1"
    local target="$2"
    local command_name="${3:-$(basename "$target")}"
    local force="${4:-false}"

    if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
        return 0  # Already correct
    fi

    if _create_symlink_raw "$source" "$target" "$force" "false"; then
        success "Created $command_name command symlink"
        return 0
    else
        error "Failed to create $command_name symlink"
        return 1
    fi
}

# ==============================================================================
# Layer 3: Low-level implementation
# ==============================================================================

# CRITICAL: This is the ONLY function that should call ln -s
# All other symlink creation MUST go through this function
_create_symlink_raw() {
    local source="$1"
    local target="$2"
    local force="${3:-false}"
    local allow_existing="${4:-false}"

    # Validate parameters
    if [[ -z "$source" ]] || [[ -z "$target" ]]; then
        error "Source and target are required for symlink creation" >&2
        return 1
    fi

    # Check if source exists (unless it's a special case)
    if [[ ! -e "$source" ]] && [[ ! -L "$source" ]]; then
        # Some symlinks point to paths that will be created later
        # This is acceptable for certain use cases
        [[ "$allow_existing" != "true" ]] && warning "Source does not exist: $source" >&2
    fi

    # Handle existing target
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        if [[ "$force" == "true" ]]; then
            rm -rf "$target" 2>/dev/null || {
                error "Failed to remove existing target: $target" >&2
                return 1
            }
        elif [[ "$allow_existing" != "true" ]]; then
            # Target exists and we're not forcing
            return 1
        fi
    fi

    # Create parent directory if needed
    local parent_dir=$(dirname "$target")
    if [[ ! -d "$parent_dir" ]]; then
        mkdir -p "$parent_dir" 2>/dev/null || {
            error "Failed to create parent directory: $parent_dir" >&2
            return 1
        }
    fi

    # CREATE THE SYMLINK - THE ONLY ln -s IN THE ENTIRE CODEBASE
    # Using -- to handle paths with spaces and special characters
    if ln -s -- "$source" "$target" 2>/dev/null; then
        return 0
    else
        error "Failed to create symlink: $target → $source" >&2
        return 1
    fi
}