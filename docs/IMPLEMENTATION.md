# Microdots Technical Implementation

---
**Document**: IMPLEMENTATION.md  
**Last Updated**: 2025-09-12  
**Version**: 2.0  
**Related Documentation**:
- [Main Architecture Guide](../MICRODOTS.md) - Complete architectural philosophy
- [Documentation Hub](README.md) - Documentation navigation
- [Dotlocal System](LOCAL_OVERRIDES.md) - Private configuration details  
- [UI Standards](UI_STYLE_GUIDE.md) - Output formatting requirements
- [System Compliance](COMPLIANCE.md) - Current system status
- [Terminology Reference](GLOSSARY.md) - Complete definitions and commands
---

## Table of Contents

- [Overview](#overview)
- [Core Infrastructure](#core-infrastructure-core)
- [Implementation Mechanisms](#implementation-mechanisms)
- [Modular Subtopics](#modular-subtopics)
- [Installation Flow](#installation-flow)
- [Adding New Topics](#adding-new-topics)
- [Common Functions](#common-functions-corelibcommonsh)
- [Best Practices](#best-practices)
- [Environment Variables](#environment-variables)
- [File Loading Order](#file-loading-order-zsh)
- [Debugging and Error Handling](#debugging-and-error-handling)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)

## Overview

This document provides technical implementation details for the Microdots system. For conceptual architecture and philosophy, see [MICRODOTS.md](../MICRODOTS.md). This guide focuses on the practical aspects of how the system operates internally.

## Core Infrastructure (`core/`)

The `core/` directory contains the foundational infrastructure that powers the dotfiles system:

```
core/
├── dots                    # Main CLI wrapper
├── commands/              # Core commands
│   ├── bootstrap          # Initial setup
│   ├── install           # Topic installer
│   └── update            # System updater
└── lib/                  # Shared libraries
    └── common.sh         # Common functions
```

### Key Components

- **`dots`**: The main CLI interface that routes commands to appropriate subcommands
- **`bootstrap`**: Sets up initial configuration (gitconfig, symlinks, Homebrew)
- **`install`**: Dynamically discovers and runs all topic installers
- **`update`**: Updates dotfiles, packages, and configurations
- **`common.sh`**: Shared utility functions used across all scripts

## Implementation Mechanisms

### Dynamic Discovery Implementation

The system uses filesystem conventions for automatic discovery:

```bash
# Installation discovery (from core/commands/install)
find . -type f -name "install.sh" -not -path "./core/*"

# Configuration discovery (from zsh/zshrc.symlink)
for config ($ZSH/**/*.zsh); do
  source $config
done

# Symlink discovery (from core/commands/relink)
find . -name "*.symlink" -not -path "./core/*"
```

### Path Resolution

```bash
# Homebrew path detection (handles Intel/Silicon)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
```

## Modular Subtopics

Topics can contain subtopics for further organization. The `claude/` topic demonstrates this:

```
claude/
├── install.sh           # Main installer (discovers subtopics)
├── agents/             # Agent definitions
│   └── install.sh      # Subtopic installer
├── commands/           # Command definitions  
│   └── install.sh      # Subtopic installer
├── global/             # Global configs
│   └── install.sh      # Subtopic installer
└── mcp/                # MCP servers
    └── install.sh      # Subtopic installer
```

Each subtopic:
- Has its own `install.sh` script
- Is completely self-contained
- Can be added/removed without affecting others
- Is automatically discovered by the parent installer

## Installation Flow

### 1. Bootstrap (`dots bootstrap`)

```bash
dots bootstrap [--install]
```

1. Sets up gitconfig with user information
2. Creates initial symlinks from `*.symlink` files
3. Installs Homebrew (macOS)
4. Optionally runs full installation with `--install`

### 2. Install (`dots install`)

```bash
dots install
```

1. Runs Homebrew bundle to install packages
2. Discovers all topics with `install.sh` scripts
3. Executes each installer in sequence
4. Reports success/failure for each topic

### 3. Update (`dots update`)

```bash
dots update
```

1. Pulls latest dotfiles changes
2. Updates macOS settings (if applicable)
3. Updates and upgrades Homebrew packages
4. Runs all topic installers to update configs

## Adding New Topics

### Configuration-Only Topic (No install.sh needed)

For topics that only provide configuration files, aliases, and shell functions:

```bash
my-topic/
├── config.symlink       # Will be linked to ~/.config
├── aliases.zsh          # Will be sourced by shell
└── functions.zsh        # Helper functions
```

**No install.sh required** - This topic relies on existing system tools and only provides configuration.

### Topic with Dependencies (install.sh required)

Add an `install.sh` when your topic needs to install external tools or configure system settings:

```bash
#!/usr/bin/env bash
set -e

# Get directories
TOPIC_DIR="$(cd "$(dirname "$0")" && pwd -P)"
DOTFILES_ROOT="$(dirname "$TOPIC_DIR")"
CORE_DIR="$DOTFILES_ROOT/core"

# Source common functions
source "$CORE_DIR/lib/common.sh"

info "Installing my-topic..."

# Your installation logic here
# ...

success "my-topic installed!"
```

### Topic with Subtopics

Follow the claude/ pattern for nested organization:

```bash
my-topic/
├── install.sh           # Discovers subtopics
├── subtopic-a/
│   └── install.sh
└── subtopic-b/
    └── install.sh
```

## Common Functions (`core/lib/common.sh`)

Available utility functions:

- **Output Functions**:
  - `info "message"` - Information message
  - `success "message"` - Success message
  - `warning "message"` - Warning message
  - `error "message"` - Error message

- **Symlink Management**:
  - `create_symlink src dst name` - Create symlink with feedback
  - `verify_symlink link` - Check if symlink is valid
  - `clean_broken_symlinks dir` - Remove broken symlinks

- **Directory Operations**:
  - `ensure_directory dir` - Create directory if needed
  - `count_files dir pattern` - Count matching files
  - `has_files dir pattern` - Check if files exist
  - `process_files src dst pattern` - Batch process files

## Install Script Decision Guide

### When to CREATE install.sh:

✅ **External Dependencies**
- Installing packages via Homebrew, apt, yum, etc.
- Downloading tools from the internet
- Compiling software from source

✅ **System Configuration** 
- Configuring system services or daemons
- Setting up complex directory structures
- Modifying system files or permissions

✅ **Complex Setup**
- Initializing databases or external resources
- Registering services with the system
- Multi-step configuration processes

### When to SKIP install.sh:

❌ **Configuration Only**
- Pure shell configuration (*.zsh files)
- Dotfile symlinks (*.symlink files)
- Environment variables and PATH setup

❌ **Existing Tools**
- Configuring tools already installed (git, zsh, vim)
- Adding aliases and functions for system commands
- Customizing behavior of pre-installed software

❌ **Documentation**
- Reference materials and documentation
- Example configurations
- Pure shell scripting without external deps

### Decision Flowchart:

```
Does your topic need to:
├─ Install external tools? ──────────────── YES → CREATE install.sh
├─ Download files from internet? ─────────── YES → CREATE install.sh  
├─ Configure system services? ────────────── YES → CREATE install.sh
├─ Set up complex directory structures? ──── YES → CREATE install.sh
└─ Only provide config/aliases/functions? ── NO ──→ SKIP install.sh
```

## Best Practices

1. **Keep Topics Self-Contained**: Each topic should work independently
2. **Use Common Functions**: Leverage `common.sh` for consistency  
3. **Create install.sh only when needed**: Don't add unnecessary installation scripts
4. **Provide Feedback**: Use info/success/warning/error functions
5. **Handle Errors Gracefully**: Check for dependencies and prerequisites
6. **Document Topics**: Include README.md in each topic
7. **Test Modularity**: Ensure topics can be added/removed cleanly

## Environment Variables

- `$DOTFILES_ROOT`: Path to dotfiles directory (usually `~/.dotfiles`)
- `$ZSH`: Same as `$DOTFILES_ROOT` (for compatibility)
- `$PROJECTS`: Default project directory (usually `~/Code`)

## File Loading Order (zsh)

1. All `*/path.zsh` files (PATH setup)
2. All other `*.zsh` files except completions
3. `compinit` (initialize autocomplete)
4. All `*/completion.zsh` files

## Debugging and Error Handling

### Diagnostic Techniques

#### Shell Loading Debug
```bash
# Debug shell initialization with timing
ZSH=~/.dotfiles zsh -x -c 'source ~/.zshrc' 2>&1 | ts '%.s' > startup.log

# Debug specific topic loading
ZSH=~/.dotfiles zsh -x -c 'source ~/.zshrc' 2>&1 | grep topic-name

# Test configuration syntax
zsh -n ~/.dotfiles/topic/config.zsh
```

#### Symlink Diagnosis
```bash
# Check symlink health
dots status --symlinks

# Find broken symlinks
find ~ -maxdepth 1 -type l ! -exec test -e {} \; -print

# Verify symlink targets
ls -la ~/.dotfiles/**/*.symlink | while read line; do
  target=$(echo "$line" | awk '{print $NF}')
  link=$(basename "$target" .symlink)
  echo "Checking: $HOME/.$link -> $target"
  ls -la "$HOME/.$link"
done
```

#### Topic Discovery Debug
```bash
# Show all discovered topics
find ~/.dotfiles -mindepth 1 -maxdepth 1 -type d -not -name core -not -name docs

# Check install script discovery
find ~/.dotfiles -name "install.sh" -not -path "./core/*" -exec echo "Found: {}" \;

# Test topic loading order
for stage in path config completion; do
  echo "=== $stage stage ==="
  find ~/.dotfiles -name "*${stage}*.zsh" -exec basename {} \;
done
```

### Error Handling Patterns

#### Defensive Function Pattern
```bash
# Template for robust functions
safe_operation() {
  local operation="$1"
  local target="$2"
  
  # Input validation
  [[ -z "$operation" ]] && { error "Operation required"; return 1; }
  [[ -z "$target" ]] && { error "Target required"; return 1; }
  
  # Dependency check
  command -v "$operation" >/dev/null 2>&1 || { 
    warning "$operation not found, skipping"
    return 0
  }
  
  # Safe execution with error handling
  if ! "$operation" "$target" 2>/dev/null; then
    error "Failed to $operation $target"
    return 1
  fi
  
  success "$operation completed successfully"
  return 0
}
```

#### Configuration Validation
```bash
# Validate configuration files before sourcing
validate_config() {
  local config_file="$1"
  
  # Check file exists and is readable
  [[ -f "$config_file" ]] || { error "Config not found: $config_file"; return 1; }
  [[ -r "$config_file" ]] || { error "Config not readable: $config_file"; return 1; }
  
  # Check for obvious issues
  if grep -q "rm -rf /" "$config_file"; then
    error "Dangerous command detected in $config_file"
    return 1
  fi
  
  # Syntax check
  if ! zsh -n "$config_file" 2>/dev/null; then
    error "Syntax error in $config_file"
    return 1
  fi
  
  return 0
}
```

#### Installation Error Recovery
```bash
# Robust installation with rollback
install_with_rollback() {
  local topic="$1"
  local backup_dir="/tmp/dotfiles-backup-$$"
  
  # Create backup
  mkdir -p "$backup_dir"
  
  # Backup existing files
  find ~/."$topic"* -maxdepth 0 2>/dev/null | while read file; do
    cp -r "$file" "$backup_dir/" 2>/dev/null
  done
  
  # Attempt installation
  if ! "$topic/install.sh"; then
    error "Installation failed, rolling back"
    
    # Restore backup
    find "$backup_dir" -mindepth 1 2>/dev/null | while read backup; do
      restore_file=$(basename "$backup")
      cp -r "$backup" "$HOME/.$restore_file" 2>/dev/null
    done
    
    rm -rf "$backup_dir"
    return 1
  fi
  
  # Clean up backup on success
  rm -rf "$backup_dir"
  success "Installation completed successfully"
  return 0
}
```

### Common Error Patterns and Solutions

#### "Command not found" Errors
```bash
# Problem: Tool not in PATH after installation
# Debug: Check PATH setup
echo $PATH | tr ':' '\n' | grep -E "(homebrew|local)" | head -5

# Solution: Fix path.zsh in topic
# Ensure tools are added to PATH in Stage 1:
if [[ -x "/opt/homebrew/bin/tool" ]]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi
```

#### "Permission denied" Errors
```bash
# Problem: Script permissions
# Debug: Check permissions
ls -la ~/.dotfiles/*/install.sh | grep -v "rwx"

# Solution: Fix permissions
find ~/.dotfiles -name "install.sh" -exec chmod +x {} \;
```

#### "File exists" Conflicts
```bash
# Problem: Symlink conflicts during bootstrap
# Debug: Find conflicts
dots relink --dry-run 2>&1 | grep -i exist

# Solution: Handle conflicts systematically
handle_conflict() {
  local source="$1"
  local target="$2"
  
  if [[ -e "$target" && ! -L "$target" ]]; then
    warning "Backing up existing $target"
    mv "$target" "${target}.backup.$(date +%s)"
  fi
  
  create_symlink "$source" "$target" "$(basename "$target")"
}
```

#### Loading Order Issues
```bash
# Problem: Completions loaded before compinit
# Debug: Check loading sequence
zsh -x -c 'source ~/.zshrc 2>&1' | grep -E "(compinit|completion)" | head -10

# Solution: Ensure proper stage separation
# path.zsh: Stage 1 (PATH only)
# *.zsh: Stage 2 (config, not completions)  
# completion.zsh: Stage 4 (after compinit)
```

### Error Reporting and Logging

#### Structured Error Reporting
```bash
# Enhanced error function with context
error_with_context() {
  local message="$1"
  local context="$2"
  local solution="${3:-See documentation for solutions}"
  
  {
    echo "ERROR: $message"
    echo "CONTEXT: $context"  
    echo "SOLUTION: $solution"
    echo "TIMESTAMP: $(date)"
    echo "ENVIRONMENT: $(uname -a)"
    echo "---"
  } >&2
  
  # Log to file if DEBUG enabled
  [[ "$DEBUG" == "true" ]] && {
    echo "$(date): ERROR - $message ($context)" >> ~/.dotfiles/debug.log
  }
}
```

#### Performance Profiling
```bash
# Profile shell startup time
profile_startup() {
  local iterations=${1:-5}
  local total_time=0
  
  for i in $(seq 1 $iterations); do
    start_time=$(date +%s.%N)
    zsh -i -c exit >/dev/null 2>&1
    end_time=$(date +%s.%N)
    
    iteration_time=$(echo "$end_time - $start_time" | bc)
    total_time=$(echo "$total_time + $iteration_time" | bc)
    
    echo "Iteration $i: ${iteration_time}s"
  done
  
  average_time=$(echo "scale=3; $total_time / $iterations" | bc)
  echo "Average startup time: ${average_time}s"
}
```

## Performance Optimization

### Startup Performance

#### Lazy Loading Pattern
```bash
# Expensive operations should be lazy-loaded
lazy_load_tool() {
  if ! command -v expensive_tool >/dev/null 2>&1; then
    return
  fi
  
  # Replace alias with actual function on first use
  expensive_command() {
    unfunction expensive_command
    eval "$(expensive_tool init)"
    expensive_command "$@"
  }
}
```

#### Caching Strategies
```bash
# Cache expensive computations
cache_dir="$HOME/.cache/dotfiles"
mkdir -p "$cache_dir"

get_with_cache() {
  local cache_key="$1"
  local cache_file="$cache_dir/$cache_key"
  local cache_ttl="${2:-3600}" # 1 hour default
  
  # Check cache validity
  if [[ -f "$cache_file" ]]; then
    local cache_age=$(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || stat -c %Y "$cache_file") ))
    if [[ $cache_age -lt $cache_ttl ]]; then
      cat "$cache_file"
      return 0
    fi
  fi
  
  # Generate and cache result
  expensive_operation > "$cache_file"
  cat "$cache_file"
}
```

#### Parallel Loading
```bash
# Load multiple topics in parallel where safe
parallel_load() {
  local pids=()
  
  # Start background processes
  for topic in ~/.dotfiles/*/path.zsh; do
    (source "$topic") &
    pids+=($!)
  done
  
  # Wait for all to complete
  for pid in "${pids[@]}"; do
    wait "$pid"
  done
}
```

### Resource Management

#### Memory Usage Optimization
```bash
# Minimize global namespace pollution
clean_namespace() {
  # Unset temporary variables
  unset temp_var setup_var config_temp
  
  # Clean up functions that are no longer needed
  unfunction setup_helper _internal_function
  
  # Clear arrays that were used for setup
  unset setup_array config_list
}

# Call after topic setup completes
trap clean_namespace EXIT
```

#### File System Optimization
```bash
# Reduce file system calls
cache_file_checks() {
  declare -A file_exists_cache
  
  file_exists() {
    local file="$1"
    
    if [[ -z "${file_exists_cache[$file]}" ]]; then
      if [[ -f "$file" ]]; then
        file_exists_cache[$file]="true"
      else
        file_exists_cache[$file]="false"
      fi
    fi
    
    [[ "${file_exists_cache[$file]}" == "true" ]]
  }
}
```

## Troubleshooting

### Command Not Found

Ensure `~/.dotfiles/bin` is in your PATH:

```bash
echo $PATH | grep -q dotfiles/bin || echo 'export PATH="$HOME/.dotfiles/bin:$PATH"' >> ~/.zshrc
```

### Topic Not Installing

Check that:
1. The topic has an executable `install.sh`
2. The script sources `core/lib/common.sh`
3. No syntax errors: `bash -n topic/install.sh`

### Symlinks Not Created

Verify:
1. Files end with `.symlink`
2. No conflicts in `$HOME`
3. Run `dots bootstrap` to create symlinks

## Contributing

When adding new functionality:

1. Decide if it's a new topic or fits in existing one
2. Create self-contained directory structure
3. Write installation script if needed
4. Test addition and removal
5. Update documentation

The modular architecture ensures your dotfiles remain maintainable, extensible, and easy to understand!