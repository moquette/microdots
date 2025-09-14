#!/usr/bin/env bash
# CRITICAL: Path resolution and dotlocal discovery for the Microdots system
# Provides centralized 5-level auto-discovery with robust fallback handling

set -euo pipefail
IFS=$'\n\t'

# Source common library for UI functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [[ -f "$SCRIPT_DIR/common.sh" ]]; then
    source "$SCRIPT_DIR/common.sh"
else
    # Fallback functions if common.sh not available
    info() { echo "[INFO] $1"; }
    success() { echo "[SUCCESS] $1"; }
    warning() { echo "[WARNING] $1"; }
    error() { echo "[ERROR] $1" >&2; }
    expand_path() { echo "${1/#\~/$HOME}"; }
fi

# Global variables for caching discovery results
DOTLOCAL_DISCOVERY_CACHE=""
DOTLOCAL_DISCOVERY_METHOD=""
DOTLOCAL_CONFIG_LOADED=""

# Load configuration from dotfiles.conf
load_dotfiles_config() {
    local dotfiles_root="${1:-$HOME/.dotfiles}"
    local config_file="$dotfiles_root/dotfiles.conf"

    # Reset config variables
    unset DOTLOCAL BACKUP_PATH AUTO_SNAPSHOT

    if [[ -f "$config_file" ]]; then
        # Source only variable assignments, not commands
        eval "$(grep '^[A-Z_]*=' "$config_file" 2>/dev/null || true)"
        DOTLOCAL_CONFIG_LOADED="true"
    else
        DOTLOCAL_CONFIG_LOADED="false"
    fi
}

# 5-level dotlocal auto-discovery
# CRITICAL: This function is used in command substitution - NO OUTPUT to stdout except the result!
discover_dotlocal_path() {
    local dotfiles_root="${1:-$HOME/.dotfiles}"
    local verbose="${2:-false}"

    # Return cached result if available
    if [[ -n "$DOTLOCAL_DISCOVERY_CACHE" ]]; then
        echo "$DOTLOCAL_DISCOVERY_CACHE"
        return 0
    fi

    local discovered_path=""
    local discovery_method=""

    # CRITICAL: All debug output goes to stderr to avoid contaminating command substitution
    [[ "$verbose" == "true" ]] && info "Starting 5-level dotlocal auto-discovery..." >&2

    # Level 1: Check dotfiles.conf for explicit configuration (highest priority)
    load_dotfiles_config "$dotfiles_root"
    if [[ -n "${DOTLOCAL:-}" ]]; then
        local config_dotlocal=$(expand_path "${DOTLOCAL:-}")
        if [[ -d "$config_dotlocal" ]]; then
            discovered_path="$config_dotlocal"
            discovery_method="dotfiles.conf (explicit configuration)"
            [[ "$verbose" == "true" ]] && info "✓ Level 1: Found via dotfiles.conf: $DOTLOCAL" >&2
        else
            [[ "$verbose" == "true" ]] && warning "Level 1: dotfiles.conf specifies DOTLOCAL='$DOTLOCAL' but directory doesn't exist" >&2
        fi
    fi

    # Level 2: Check for existing symlink in dotfiles directory
    if [[ -z "$discovered_path" ]]; then
        local existing_symlink="$dotfiles_root/.dotlocal"
        if [[ -L "$existing_symlink" ]]; then
            local symlink_target=$(readlink "$existing_symlink")
            if [[ -d "$symlink_target" ]]; then
                discovered_path="$symlink_target"
                discovery_method="existing .dotlocal symlink"
                [[ "$verbose" == "true" ]] && info "✓ Level 2: Found via existing symlink: $symlink_target" >&2
            else
                [[ "$verbose" == "true" ]] && warning "Level 2: Existing .dotlocal symlink points to non-existent directory: $symlink_target" >&2
            fi
        fi
    fi

    # Level 3: Check for existing directory in dotfiles
    if [[ -z "$discovered_path" ]]; then
        local existing_dir="$dotfiles_root/.dotlocal"
        if [[ -d "$existing_dir" ]] && [[ ! -L "$existing_dir" ]]; then
            discovered_path="$existing_dir"
            discovery_method="existing .dotlocal directory"
            [[ "$verbose" == "true" ]] && info "✓ Level 3: Found existing directory: $existing_dir" >&2
        fi
    fi

    # Level 4: Check standard hidden directory in home
    if [[ -z "$discovered_path" ]]; then
        local home_dotlocal="$HOME/.dotlocal"
        if [[ -d "$home_dotlocal" ]]; then
            discovered_path="$home_dotlocal"
            discovery_method="standard ~/.dotlocal directory"
            [[ "$verbose" == "true" ]] && info "✓ Level 4: Found standard directory: $home_dotlocal" >&2
        fi
    fi

    # Level 5: Auto-discover cloud storage locations
    if [[ -z "$discovered_path" ]]; then
        [[ "$verbose" == "true" ]] && info "Level 5: Scanning for cloud storage locations..." >&2

        # Define cloud locations to check
        local cloud_locations=(
            "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal"
            "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotfiles/dotlocal"
            "$HOME/Dropbox/Dotlocal"
            "$HOME/Google Drive/Dotlocal"
            "$HOME/OneDrive/Dotlocal"
            "/Volumes/My Shared Files/Dotlocal"
        )

        for location in "${cloud_locations[@]}"; do
            if [[ -d "$location" ]]; then
                discovered_path="$location"
                discovery_method="cloud storage auto-discovery"
                local cloud_type="unknown"

                # Identify cloud service type
                case "$location" in
                    *"CloudDocs"*) cloud_type="iCloud Drive" ;;
                    *"Dropbox"*) cloud_type="Dropbox" ;;
                    *"Google Drive"*) cloud_type="Google Drive" ;;
                    *"OneDrive"*) cloud_type="OneDrive" ;;
                    *"My Shared Files"*) cloud_type="Network Storage" ;;
                esac

                [[ "$verbose" == "true" ]] && info "✓ Level 5: Found via $cloud_type: $location" >&2
                break
            fi
        done
    fi

    # Cache results
    DOTLOCAL_DISCOVERY_CACHE="$discovered_path"
    DOTLOCAL_DISCOVERY_METHOD="$discovery_method"

    # CRITICAL: Only the actual result goes to stdout for command substitution
    echo "$discovered_path"
}

# Get discovery method for last discovery
get_dotlocal_discovery_method() {
    echo "$DOTLOCAL_DISCOVERY_METHOD"
}

# Create dotlocal directory and infrastructure
setup_dotlocal_infrastructure() {
    local dotlocal_path="$1"
    local dotfiles_root="${2:-$HOME/.dotfiles}"
    local force="${3:-false}"
    local verbose="${4:-true}"

    # Create dotlocal directory if it doesn't exist
    if [[ ! -d "$dotlocal_path" ]]; then
        mkdir -p "$dotlocal_path"
        [[ "$verbose" == "true" ]] && success "Created dotlocal directory: $dotlocal_path" >&2
    fi

    # Create .dotlocal symlink in dotfiles directory
    local dotlocal_symlink="$dotfiles_root/.dotlocal"

    # Source symlink library for consistent infrastructure creation
    source "${BASH_SOURCE[0]%/*}/symlink.sh"

    if [[ ! -e "$dotlocal_symlink" ]]; then
        create_infrastructure_symlink "$dotlocal_path" "$dotlocal_symlink" ".dotlocal" "false" "$verbose"
    elif [[ -L "$dotlocal_symlink" ]]; then
        local current_target=$(readlink "$dotlocal_symlink")
        if [[ "$current_target" != "$dotlocal_path" ]] || [[ "$force" == "true" ]]; then
            create_infrastructure_symlink "$dotlocal_path" "$dotlocal_symlink" ".dotlocal" "true" "$verbose"
        fi
    elif [[ -d "$dotlocal_symlink" ]]; then
        if [[ "$(cd "$dotlocal_symlink" && pwd -P)" != "$(cd "$dotlocal_path" && pwd -P)" ]]; then
            [[ "$verbose" == "true" ]] && warning ".dotlocal exists as directory but doesn't match target path" >&2
        fi
    else
        [[ "$verbose" == "true" ]] && warning ".dotlocal exists but is neither symlink nor directory" >&2
    fi

    # Create infrastructure symlinks inside dotlocal
    # These provide access to shared infrastructure and documentation
    # See INFRASTRUCTURE_SYMLINKS.md for architectural justification
    local infrastructure_symlinks=(
        "core:$dotfiles_root/core"                    # UI library and utilities
        "docs:$dotfiles_root/docs"                    # Documentation directory
        "MICRODOTS.md:$dotfiles_root/MICRODOTS.md"    # Architecture guide
        "CLAUDE.md:$dotfiles_root/CLAUDE.md"          # AI agent configuration
        "TASKS.md:$dotfiles_root/TASKS.md"            # Project tasks
        "COMPLIANCE.md:$dotfiles_root/docs/architecture/COMPLIANCE.md"  # Compliance documentation
    )

    for symlink_spec in "${infrastructure_symlinks[@]}"; do
        local name="${symlink_spec%%:*}"
        local target="${symlink_spec#*:}"
        local symlink_path="$dotlocal_path/$name"

        # Enhanced target validation
        if [[ ! -e "$target" ]]; then
            [[ "$verbose" == "true" ]] && warning "Infrastructure target missing: $target" >&2
            continue
        elif [[ ! -r "$target" ]]; then
            [[ "$verbose" == "true" ]] && warning "Infrastructure target not readable: $target" >&2
            continue
        fi

        # Create or update symlink using infrastructure function
        create_infrastructure_symlink "$target" "$symlink_path" "$name" "$force" "$verbose"
    done
}

# Validate all infrastructure symlinks are healthy
validate_infrastructure_symlinks() {
    local dotlocal_path="${1:-$DISCOVERED_DOTLOCAL_PATH}"
    local dotfiles_root="${2:-$HOME/.dotfiles}"
    local verbose="${3:-false}"
    local issues=0

    # Check if dotlocal path is provided
    if [[ -z "$dotlocal_path" ]]; then
        [[ "$verbose" == "true" ]] && error "No dotlocal path provided for validation" >&2
        return 1
    fi

    # Define expected infrastructure symlinks
    local infrastructure_symlinks=(
        "core:$dotfiles_root/core"
        "docs:$dotfiles_root/docs"
        "MICRODOTS.md:$dotfiles_root/MICRODOTS.md"
        "CLAUDE.md:$dotfiles_root/CLAUDE.md"
        "TASKS.md:$dotfiles_root/TASKS.md"
        "COMPLIANCE.md:$dotfiles_root/docs/architecture/COMPLIANCE.md"
    )

    [[ "$verbose" == "true" ]] && info "Validating infrastructure symlinks in: $dotlocal_path" >&2

    for symlink_spec in "${infrastructure_symlinks[@]}"; do
        local name="${symlink_spec%%:*}"
        local expected_target="${symlink_spec#*:}"
        local symlink_path="$dotlocal_path/$name"

        # Check if symlink exists
        if [[ ! -e "$symlink_path" ]]; then
            [[ "$verbose" == "true" ]] && warning "Missing infrastructure symlink: $name" >&2
            ((issues++))
        elif [[ ! -L "$symlink_path" ]]; then
            [[ "$verbose" == "true" ]] && warning "Not a symlink: $name (is a $(file -b "$symlink_path"))" >&2
            ((issues++))
        else
            # Check if symlink is broken
            if [[ ! -e "$symlink_path" ]]; then
                [[ "$verbose" == "true" ]] && error "Broken symlink: $name" >&2
                ((issues++))
            else
                # Check if symlink points to correct target
                local actual_target=$(readlink "$symlink_path")
                if [[ "$actual_target" != "$expected_target" ]]; then
                    [[ "$verbose" == "true" ]] && warning "Wrong symlink target for $name: $actual_target (expected: $expected_target)" >&2
                    ((issues++))
                fi
            fi
        fi
    done

    if [[ "$verbose" == "true" ]]; then
        if [[ $issues -eq 0 ]]; then
            success "All infrastructure symlinks are healthy" >&2
        else
            warning "Found $issues infrastructure symlink issue(s)" >&2
        fi
    fi

    return $issues
}

# Repair corrupted infrastructure symlinks
repair_infrastructure() {
    local dotlocal_path="${1:-$DISCOVERED_DOTLOCAL_PATH}"
    local dotfiles_root="${2:-$HOME/.dotfiles}"
    local verbose="${3:-true}"

    # Check if dotlocal path is provided
    if [[ -z "$dotlocal_path" ]]; then
        # Try to discover it
        dotlocal_path=$(discover_dotlocal_path "$dotfiles_root" "$verbose")
        if [[ -z "$dotlocal_path" ]]; then
            [[ "$verbose" == "true" ]] && error "Cannot repair: No dotlocal path found" >&2
            return 1
        fi
    fi

    [[ "$verbose" == "true" ]] && header "🔧 Infrastructure Repair Mode" >&2
    [[ "$verbose" == "true" ]] && info "Repairing infrastructure in: $dotlocal_path" >&2

    # First validate to see what needs repair
    local issues=0
    validate_infrastructure_symlinks "$dotlocal_path" "$dotfiles_root" "false" || issues=$?

    if [[ $issues -eq 0 ]]; then
        [[ "$verbose" == "true" ]] && success "No infrastructure issues found - system healthy" >&2
        return 0
    fi

    [[ "$verbose" == "true" ]] && warning "Found $issues issue(s) - starting repair..." >&2

    # Remove broken or incorrect symlinks
    local infrastructure_names=("core" "docs" "MICRODOTS.md" "CLAUDE.md" "TASKS.md" "COMPLIANCE.md")
    for name in "${infrastructure_names[@]}"; do
        local symlink_path="$dotlocal_path/$name"

        if [[ -L "$symlink_path" ]]; then
            # Check if broken or pointing to wrong location
            if [[ ! -e "$symlink_path" ]]; then
                [[ "$verbose" == "true" ]] && info "Removing broken symlink: $name" >&2
                rm -f "$symlink_path"
            else
                # Verify target is correct
                local actual_target=$(readlink "$symlink_path")
                local expected_targets=(
                    "$dotfiles_root/core"
                    "$dotfiles_root/docs"
                    "$dotfiles_root/MICRODOTS.md"
                    "$dotfiles_root/CLAUDE.md"
                    "$dotfiles_root/TASKS.md"
                    "$dotfiles_root/docs/architecture/COMPLIANCE.md"
                )

                # Check if it points to any expected location
                local is_correct=false
                for expected in "${expected_targets[@]}"; do
                    if [[ "$actual_target" == "$expected" ]] && [[ "$(basename "$expected")" == "$name" || "$(basename "$(dirname "$expected")")" == "$name" ]]; then
                        is_correct=true
                        break
                    fi
                done

                if [[ "$is_correct" == "false" ]]; then
                    [[ "$verbose" == "true" ]] && info "Removing incorrect symlink: $name" >&2
                    rm -f "$symlink_path"
                fi
            fi
        elif [[ -e "$symlink_path" ]]; then
            # Not a symlink but something else exists
            [[ "$verbose" == "true" ]] && warning "Backing up non-symlink: $name to ${name}.backup" >&2
            mv "$symlink_path" "${symlink_path}.backup.$(date +%s)"
        fi
    done

    # Force recreation of all infrastructure
    [[ "$verbose" == "true" ]] && progress "Recreating infrastructure symlinks..." >&2
    setup_dotlocal_infrastructure "$dotlocal_path" "$dotfiles_root" "true" "$verbose"

    # Validate the repair
    [[ "$verbose" == "true" ]] && progress "Validating repair..." >&2
    local remaining_issues=0
    validate_infrastructure_symlinks "$dotlocal_path" "$dotfiles_root" "false" || remaining_issues=$?

    if [[ $remaining_issues -eq 0 ]]; then
        [[ "$verbose" == "true" ]] && success "✅ Infrastructure repair complete - all symlinks healthy" >&2
        return 0
    else
        [[ "$verbose" == "true" ]] && error "⚠️ Repair incomplete - $remaining_issues issue(s) remain" >&2
        [[ "$verbose" == "true" ]] && info "Run 'dots status --verbose' for details" >&2
        return $remaining_issues
    fi
}

# Create dotfiles.conf with discovered cloud location
create_dotfiles_config() {
    local dotlocal_path="$1"
    local dotfiles_root="${2:-$HOME/.dotfiles}"
    local discovery_method="${3:-}"
    local verbose="${4:-true}"

    local config_file="$dotfiles_root/dotfiles.conf"

    # Only create config if we discovered a non-default location
    if [[ "$discovery_method" == "cloud storage auto-discovery" ]] && [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << EOF
# Dotfiles Configuration
# Auto-generated during bootstrap

# Local configuration directory (discovered via cloud auto-discovery)
DOTLOCAL="$dotlocal_path"
EOF
        [[ "$verbose" == "true" ]] && success "Created dotfiles.conf with auto-discovered location" >&2
    fi
}

# Get the type of local configuration (for status reporting)
get_dotlocal_type() {
    local dotfiles_root="${1:-$HOME/.dotfiles}"

    # Check if there's an explicit config
    load_dotfiles_config "$dotfiles_root"
    if [[ -n "${DOTLOCAL:-}" ]]; then
        echo "explicit"
        return 0
    fi

    # Check for symlink
    local dotlocal_symlink="$dotfiles_root/.dotlocal"
    if [[ -L "$dotlocal_symlink" ]]; then
        echo "symlink"
        return 0
    fi

    # Check for directory
    if [[ -d "$dotlocal_symlink" ]]; then
        echo "directory"
        return 0
    fi

    # Check for standard location
    if [[ -d "$HOME/.dotlocal" ]]; then
        echo "standard"
        return 0
    fi

    echo "none"
}

# Resolve dotlocal path with full auto-discovery and setup
resolve_dotlocal_path() {
    local dotfiles_root="${1:-$HOME/.dotfiles}"
    local create_if_missing="${2:-true}"
    local verbose="${3:-false}"

    # Try discovery first
    local discovered_path=$(discover_dotlocal_path "$dotfiles_root" "$verbose")
    local discovery_method=$(get_dotlocal_discovery_method)

    # If nothing found and we should create, create default
    if [[ -z "$discovered_path" ]] && [[ "$create_if_missing" == "true" ]]; then
        local default_location="$HOME/.dotlocal"
        [[ "$verbose" == "true" ]] && info "No existing dotlocal directory found, creating default: $default_location" >&2

        mkdir -p "$default_location"
        discovered_path="$default_location"
        discovery_method="created default directory"

        # Update cache
        DOTLOCAL_DISCOVERY_CACHE="$discovered_path"
        DOTLOCAL_DISCOVERY_METHOD="$discovery_method"
    fi

    # Set up infrastructure if we have a path
    if [[ -n "$discovered_path" ]]; then
        setup_dotlocal_infrastructure "$discovered_path" "$dotfiles_root" "false" "$verbose"
        create_dotfiles_config "$discovered_path" "$dotfiles_root" "$discovery_method" "$verbose"
    fi

    echo "$discovered_path"
}

# Clear discovery cache (for testing)
clear_dotlocal_cache() {
    DOTLOCAL_DISCOVERY_CACHE=""
    DOTLOCAL_DISCOVERY_METHOD=""
    DOTLOCAL_CONFIG_LOADED=""
}

# Check if dotlocal directory exists and is accessible
validate_dotlocal_path() {
    local dotlocal_path="$1"

    if [[ -z "$dotlocal_path" ]]; then
        return 1
    fi

    if [[ ! -d "$dotlocal_path" ]]; then
        return 1
    fi

    if [[ ! -r "$dotlocal_path" ]]; then
        return 1
    fi

    if [[ ! -w "$dotlocal_path" ]]; then
        return 1
    fi

    return 0
}

# Get status information for reporting
get_dotlocal_status() {
    local dotfiles_root="${1:-$HOME/.dotfiles}"

    local discovered_path=$(discover_dotlocal_path "$dotfiles_root" false)
    local discovery_method=$(get_dotlocal_discovery_method)
    local dotlocal_type=$(get_dotlocal_type "$dotfiles_root")

    cat << EOF
{
  "path": "$discovered_path",
  "method": "$discovery_method",
  "type": "$dotlocal_type",
  "exists": $(validate_dotlocal_path "$discovered_path" && echo "true" || echo "false")
}
EOF
}