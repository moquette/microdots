# Dotfiles UI Style Guide

---
**Document**: UI_STYLE_GUIDE.md  
**Last Updated**: 2025-09-12  
**Version**: 2.0  
**Related Documentation**:
- [Documentation Hub](README.md) - Documentation navigation
- [Technical Implementation](IMPLEMENTATION.md) - System internals and UI integration
- [Dotlocal System](LOCAL_OVERRIDES.md) - Private configuration UI patterns
- [System Compliance](COMPLIANCE.md) - UI consistency validation
- [Terminology Reference](GLOSSARY.md) - UI function definitions
---

## Table of Contents

- [Overview](#overview)
- [Core Principles](#core-principles)
- [Using the UI Library](#using-the-ui-library)
- [Standard Output Patterns](#standard-output-patterns)
- [Command Examples](#command-examples)
- [Project-Specific UI Patterns](#project-specific-ui-patterns)
- [Color Usage Guidelines](#color-usage-guidelines)
- [Terminal Compatibility](#terminal-compatibility)
- [Best Practices](#best-practices)
- [Environment Variables](#environment-variables)
- [Testing Output](#testing-output)
- [Common Pitfalls to Avoid](#common-pitfalls-to-avoid)
- [Integration Checklist](#integration-checklist)

## Overview

This guide defines the unified output style for all dotfiles commands to ensure a consistent, professional user experience.

## Core Principles

1. **Consistency**: All commands use the same output patterns
2. **Clarity**: Information hierarchy is immediately clear
3. **Accessibility**: Works in all terminal environments
4. **Professional**: Clean, modern appearance

## Using the UI Library

### Basic Setup

```bash
# In any command script
source "$CORE_DIR/lib/ui.sh"
```

### Message Types

#### Headers (Major Sections)
```bash
header "🔧 Installation"
# Output: Bold text with separator line
```

#### Information Messages
```bash
info "Processing configuration files..."
# Output: › Processing configuration files...
```

#### Success Messages
```bash
success "Installation complete"
# Output: ✓ Installation complete
```

#### Warning Messages
```bash
warning "Config file missing, using defaults"
# Output: ⚠ Config file missing, using defaults (in yellow)
```

#### Error Messages
```bash
error "Failed to create symlink"
# Output: ✗ Failed to create symlink (in red, to stderr)
```

#### Progress Indicators
```bash
progress "Installing dependencies"
# Output: ⟳ Installing dependencies (in cyan)
```

### Command Structure Pattern

Every command should follow this basic structure:

```bash
#!/usr/bin/env bash

# Source UI library
source "$CORE_DIR/lib/ui.sh"

# Command header
header "🔧 Dots Bootstrap"

# Section processing
subheader "Configuration"
info "Loading configuration..."
success "Configuration loaded"

# Show progress for operations
progress "Creating symlinks"
# ... do work ...
success "Symlinks created"

# Handle errors gracefully
if [[ $error_occurred ]]; then
    error "Operation failed"
    exit 1
fi

# Summary at the end
summary "Bootstrap" $success_count $warning_count $error_count
```

## Standard Output Patterns

### Configuration Display
```bash
subheader "Configuration"
key_value "DOTFILES_ROOT" "$DOTFILES_ROOT"
key_value "DOTLOCAL_DIR" "$DOTLOCAL_DIR"
key_value "Status" "Active"
```

### Lists
```bash
subheader "Installed Topics"
list_item "git"
list_item "homebrew"
list_item "zsh"
```

### Tables
```bash
table_header "Component" "Status" "Version"
table_row "Homebrew" "Installed" "4.1.0"
table_row "Git" "Installed" "2.42.0"
```

### Status Indicators
```bash
status "Database" "running"     # Green checkmark
status "Cache" "degraded"        # Yellow warning
status "API" "failed"            # Red X
```

## Migration Examples

### Before (Inconsistent)
```bash
echo "===> Starting installation"
echo "› Processing files..."
echo "✓ Done"
echo "[OK] Completed"
```

### After (Unified)
```bash
header "🚀 Starting Installation"
progress "Processing files"
success "Processing complete"
summary "Installation" 1 0 0
```

## Command Examples

### Bootstrap Command
```bash
header "🔧 Dotfiles Bootstrap"

subheader "System Check"
progress "Checking prerequisites"
success "Git installed"
success "Homebrew installed"

subheader "Configuration"
info "Setting up gitconfig..."
success "gitconfig configured"

subheader "Symlinks"
progress "Creating symlinks"
list_item "Created ~/.zshrc"
list_item "Created ~/.gitconfig"
success "All symlinks created"

summary "Bootstrap" 5 0 0
```

### Status Command
```bash
header "📊 Dotfiles Status"

subheader "System Configuration"
key_value "Dotfiles" "$HOME/.dotfiles"
key_value "Local" "$HOME/.dotlocal"
key_value "Shell" "zsh"

subheader "Component Status"
status "Symlinks" "healthy"
status "Git" "clean"
status "Updates" "available"

subheader "Statistics"
table_header "Type" "Count"
table_row "Topics" "12"
table_row "Symlinks" "24"
table_row "Commands" "8"
```

### Maintenance Command
```bash
header "🔧 Maintenance"

subheader "Cleanup"
progress "Removing temporary files"
success "Removed 5 temp files"

subheader "Updates"
progress "Checking for updates"
warning "3 packages outdated"

subheader "Health Checks"
status "Disk Space" "healthy"
status "Symlinks" "ok"
status "Dependencies" "warning"

summary "Maintenance" 2 1 0
```

## Project-Specific UI Patterns

The Microdots project has developed several specialized UI patterns that extend the core library for domain-specific needs.

### Dotlocal Status Display

The dotlocal system uses specific patterns for showing configuration precedence and override status:

```bash
# Dotlocal system status pattern (from dots status)
subheader "Local Configuration"
key_value "Type" "Symlink"
key_value "Path" "$HOME/.dotlocal"
key_value "Status" "Active (16 topics)"

# Show precedence resolution
subheader "Precedence Resolution"
list_item "✓ Checked dotfiles.conf - not found"
list_item "✓ Checked .dotlocal symlink - found: ~/.dotlocal"
list_item "● Using: ~/.dotlocal (16 topics)"
```

### Topic Independence Validation

For compliance checking and topic validation:

```bash
# Topic compliance pattern
header "📊 System Compliance Check"

subheader "Topic Independence"
for topic in git homebrew zsh; do
  status "$topic" "independent"  # Green checkmark
done

subheader "Loading Order Validation"  
status "Stage 1 (path.zsh)" "valid"
status "Stage 2 (config)" "valid"
status "Stage 3 (compinit)" "initialized"
status "Stage 4 (completion)" "loaded"
```

### MCP Server Status

For MCP server management and status:

```bash
# MCP server status pattern
header "🔌 MCP Server Status"

subheader "Configured Servers"
table_header "Server" "Status" "Tools" "Version"
table_row "filesystem" "active" "12" "1.0.0"
table_row "context7" "active" "4" "2.1.0"
table_row "memory" "failed" "8" "1.5.2"

# Server-specific actions
subheader "Actions Required"
warning "Memory server requires restart"
info "Run: claude mcp restart memory"
```

### Installation Progress Tracking

For complex installation workflows:

```bash
# Multi-topic installation pattern
header "🚀 Topic Installation"

# Progress tracking with counts
subheader "Installation Progress (3/8 complete)"
status "git" "installed"
status "homebrew" "installed"  
status "zsh" "installed"
progress "Installing node"
list_item "docker - pending"
list_item "claude - pending"
list_item "backup - pending"
list_item "ssh - pending"
```

### Error Recovery and Rollback

For error handling and recovery operations:

```bash
# Error recovery pattern
header "🔄 System Recovery"

subheader "Detected Issues"
error "Broken symlink: ~/.zshrc"
warning "Missing dependency: node"
info "Backup available: ~/.zshrc.backup.1631234567"

subheader "Recovery Options"
list_item "1. Restore from backup"
list_item "2. Recreate from template"
list_item "3. Skip and continue"

# Recovery action
progress "Restoring ~/.zshrc from backup"
success "Recovery completed successfully"
```

### Diagnostic Output

For debugging and troubleshooting:

```bash
# Diagnostic information pattern
header "🔍 System Diagnostics"

subheader "Environment"
key_value "DOTFILES_ROOT" "$HOME/.dotfiles"
key_value "DOTLOCAL" "$HOME/.dotlocal"  
key_value "Shell" "zsh 5.8.1"
key_value "Platform" "macOS 14.0"

subheader "Loading Performance"
key_value "Startup Time" "0.234s"
key_value "Topics Loaded" "8"
key_value "Symlinks Active" "24"

subheader "Health Status"
status "Configuration" "healthy"
status "Symlinks" "healthy"
status "Dependencies" "warning"
```

### Testing and Validation Output

For test execution and validation:

```bash
# Test execution pattern  
header "🧪 System Tests"

subheader "Portability Tests"
status "Hardcoded paths" "pass"
status "User references" "pass"
status "Cross-platform" "warning"

subheader "Integration Tests"
progress "Running 85 tests"
# Real-time test results
list_item "✓ test_topic_independence (0.12s)"
list_item "✓ test_loading_order (0.08s)"
list_item "⚠ test_completion_timing (0.15s)"

summary "Testing" 83 2 0
```

These patterns ensure consistent visual presentation across all Microdots operations while providing clear, actionable information to users. Each pattern follows the core UI principles while addressing the specific needs of dotfiles management.

## Color Usage Guidelines

- **Green**: Success, healthy, active states
- **Yellow**: Warnings, degraded states, attention needed
- **Red**: Errors, failures, critical issues
- **Cyan**: Progress, ongoing operations
- **Magenta**: User prompts, questions
- **Dim**: Separators, debug output, less important info
- **Bold**: Headers, emphasis, important information

## Terminal Compatibility

The UI library automatically detects terminal capabilities:
- Full Unicode and colors in modern terminals (iTerm, Terminal.app)
- Fallback to ASCII symbols in basic terminals
- No colors when output is piped or redirected
- Respects NO_COLOR environment variable

## Best Practices

1. **Start with a header** - Every command should have a clear header
2. **Group related output** - Use subheaders to organize sections
3. **Provide feedback** - Show progress for long operations
4. **Summarize results** - End with a clear summary
5. **Handle errors gracefully** - Use proper error messages and exit codes
6. **Be consistent** - Use the same patterns across all commands
7. **Test accessibility** - Verify output in different terminals

## Environment Variables

- `DEBUG=true` - Show debug output
- `VERBOSE=true` - Show detailed information
- `NO_COLOR=1` - Disable color output
- `QUIET=true` - Minimize output (show only errors)

## Testing Output

```bash
# Test in different environments
TERM=xterm ./dots status          # Basic terminal
TERM=xterm-256color ./dots status # Modern terminal
NO_COLOR=1 ./dots status          # No colors
DEBUG=true ./dots status           # Debug mode
./dots status | cat                # Piped output
```

## Common Pitfalls to Avoid

1. Don't mix output styles (echo with info/success/error)
2. Don't use raw ANSI codes - use the UI functions
3. Don't forget to source the UI library
4. Don't output errors to stdout (use error function)
5. Don't assume Unicode support (library handles fallbacks)

## Integration Checklist

When updating a command to use the unified style:

- [ ] Source the ui.sh library
- [ ] Replace echo statements with appropriate UI functions
- [ ] Add proper headers and sections
- [ ] Use consistent status indicators
- [ ] Add summary at the end
- [ ] Test in different terminals
- [ ] Update help text to match style
- [ ] Ensure error messages go to stderr
- [ ] Handle quiet/verbose modes
- [ ] Document any custom patterns used