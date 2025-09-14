#!/bin/sh
#
# Dotfiles Core Library
# Shared functions for modular topic installation
#

# Get dotfiles root (works from any script location)
get_dotfiles_root() {
  local current_dir="$(cd "$(dirname "$0")" && pwd -P)"
  while [ "$current_dir" != "/" ]; do
    if [ -d "$current_dir/core" ] && [ -f "$current_dir/core/dots" ]; then
      echo "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
  done
  return 1
}

# Get the script directory for sourcing UI library
COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the unified UI library - THIS IS THE SINGLE SOURCE OF TRUTH
if [ -f "$COMMON_SCRIPT_DIR/ui.sh" ]; then
  source "$COMMON_SCRIPT_DIR/ui.sh"
else
  # Fallback if UI library not found - basic functions
  info() { echo "> $1"; }
  success() { echo "[OK] $1"; }
  warning() { echo "[!] $1"; }
  error() { echo "[ERROR] $1" >&2; }
fi

# Function to safely create symlinks
create_symlink() {
  local src="$1"
  local dst="$2"
  local name="$3"

  # Use the symlink library for consistent behavior
  source "${BASH_SOURCE[0]%/*}/symlink.sh"

  if create_bootstrap_symlink "$src" "$dst" "$name" "false"; then
    return 0
  else
    error "Failed to link: $name"
    return 1
  fi
}

# Function to verify symlink points to valid file
verify_symlink() {
  local link="$1"
  if [ -L "$link" ] && [ -e "$link" ]; then
    return 0
  else
    return 1
  fi
}

# Function to clean broken symlinks in a directory
clean_broken_symlinks() {
  local dir="$1"
  if [ -d "$dir" ]; then
    find "$dir" -type l ! -exec test -e {} \; -delete 2>/dev/null || true
  fi
}

# Function to create directory if it doesn't exist
ensure_directory() {
  local dir="$1"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
  return 0
}

# Function to count files in directory
count_files() {
  local dir="$1"
  local pattern="$2"
  if [ -d "$dir" ]; then
    ls "$dir"/$pattern 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

# Function to check if directory has files
has_files() {
  local dir="$1"
  local pattern="$2"
  local count=$(count_files "$dir" "$pattern")
  [ "$count" -gt 0 ]
}

# Function to process all files matching pattern
process_files() {
  local source_dir="$1"
  local target_dir="$2"
  local pattern="$3"
  local success_count=0
  local fail_count=0
  
  # Ensure target directory exists
  ensure_directory "$target_dir"
  
  # Clean broken symlinks first
  clean_broken_symlinks "$target_dir"
  
  # Process each file
  for file in "$source_dir"/$pattern; do
    if [ -f "$file" ]; then
      local filename=$(basename "$file")
      if create_symlink "$file" "$target_dir/$filename" "$filename"; then
        success_count=$((success_count + 1))
      else
        fail_count=$((fail_count + 1))
      fi
    fi
  done
  
  # Return counts via echo (shell doesn't have proper return for multiple values)
  echo "$success_count $fail_count"
}

# Function to expand tilde and other path variables
# Usage: expanded_path=$(expand_path "$path")
expand_path() {
  local path="$1"
  if [ -z "$path" ]; then
    echo ""
    return
  fi
  # Expand tilde to HOME
  path="${path/#\~/$HOME}"
  # Return the expanded path
  echo "$path"
}

# Function to get topic name from directory
get_topic_name() {
  local dir="$1"
  basename "$dir"
}

# Function to check if running from correct directory
check_directory() {
  local expected="$1"
  local current=$(basename "$(pwd)")
  if [ "$current" != "$expected" ]; then
    error "Must run from $expected directory"
    exit 1
  fi
}