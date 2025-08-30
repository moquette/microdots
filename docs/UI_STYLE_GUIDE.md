# Dotfiles UI Style Guide

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
key_value "Dotfiles" "/Users/name/.dotfiles"
key_value "Local" "/Users/name/.dotlocal"
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