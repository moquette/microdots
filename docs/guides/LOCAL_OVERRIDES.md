# Dotlocal System Documentation

---
**Document**: LOCAL_OVERRIDES.md  
**Last Updated**: 2025-09-12  
**Version**: 2.0  
**Related Documentation**:
- [Documentation Hub](README.md) - Documentation navigation
- [Main Architecture Guide](../MICRODOTS.md) - Architecture principles
- [Technical Implementation](IMPLEMENTATION.md) - System internals and mechanics
- [Migration History](MIGRATION_TO_DOTLOCAL.md) - Migration to .dotlocal naming
- [UI Standards](UI_STYLE_GUIDE.md) - Output formatting
- [Terminology Reference](GLOSSARY.md) - Commands and variable definitions
---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [How It Works](#how-it-works)
- [Quick Start](#quick-start)
- [Commands](#commands)
- [Configuration File](#configuration-file)
- [Examples](#examples)
- [Best Practices](#best-practices)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Architecture Details](#architecture-details)
- [Migration Guide](#migration-guide)
- [Complete Installation Instructions](#complete-installation-instructions)
- [Testing Checklist](#testing-checklist)
- [Core Library Organization](#core-library-organization)
- [Quick Reference](#quick-reference)

## Overview

This dotfiles repository implements a **dotlocal system** that elegantly separates public, shareable configurations from private, personal settings. The system ensures that local configurations **always win** over public ones through a sophisticated precedence mechanism.

## Key Features

- **Complete separation** of public templates and private configurations
- **Local always wins** - your personal configs override public defaults
- **Zero configuration required** - works out of the box
- **Cloud sync compatible** - store your private configs in iCloud, Dropbox, etc.
- **Progressive enhancement** - start simple, add complexity as needed

## How It Works

### 1. Five-Level Auto-Discovery

The system uses a sophisticated 5-level precedence hierarchy to automatically discover your dotlocal configuration:

**Level 1: Explicit Configuration** (Highest Priority)
- Checks `dotfiles.conf` for `DOTLOCAL` variable
- User explicitly configured path takes absolute precedence

**Level 2: Existing Symlink**
- Checks for `~/.dotfiles/.dotlocal` symlink
- Created automatically by bootstrap or cloud setup

**Level 3: Existing Directory**
- Checks for `~/.dotfiles/.dotlocal` directory
- Local directory within dotfiles repository

**Level 4: Standard Location**
- Checks for `~/.dotlocal` (default hidden directory in home)
- Created automatically if nothing else found

**Level 5: Cloud Storage Auto-Discovery** (Lowest Priority)
- Automatically scans common cloud locations:
  - iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal`)
  - Dropbox (`~/Dropbox/Dotlocal`)
  - Google Drive (`~/Google Drive/Dotlocal`)
  - OneDrive (`~/OneDrive/Dotlocal`)
  - Network volumes (`/Volumes/*/Dotlocal`)

### 2. Infrastructure Symlinks System

Once dotlocal is discovered, the system automatically creates **6 infrastructure symlinks** that provide essential shared access:

```bash
~/.dotlocal/
├── core → ~/.dotfiles/core                    # UI library and utilities
├── docs → ~/.dotfiles/docs                    # Documentation directory
├── MICRODOTS.md → ~/.dotfiles/MICRODOTS.md    # Architecture guide
├── CLAUDE.md → ~/.dotfiles/CLAUDE.md          # AI agent configuration
├── TASKS.md → ~/.dotfiles/TASKS.md            # Project tasks
└── COMPLIANCE.md → ~/.dotfiles/docs/COMPLIANCE.md  # Compliance documentation
```

These symlinks are **acceptable infrastructure dependencies** because they provide:
- Documentation access for understanding the system
- UI library for consistent tool output
- Development utilities and shared infrastructure
- They do NOT create functional coupling between microdots

### 3. Two-Layer Configuration

```
~/.dotfiles/          # Public (committed to git)
├── shell/           # Shell templates
├── git/             # Git templates
└── vim/             # Vim templates

~/.dotlocal/         # Private (never committed)
├── shell/           # Your personal shell configs
├── ssh.symlink/     # Your SSH keys
└── localrc.symlink  # Your secrets/API keys
```

### 2. Precedence System - 5-Level Auto-Discovery

The system uses intelligent 5-level auto-discovery that's now **production-ready** and thoroughly tested:

1. **dotfiles.conf** - Explicit configuration (highest priority)
2. **~/.dotfiles/.dotlocal** - Symlink to your local folder
3. **~/.dotfiles/.dotlocal** - Regular directory
4. **~/.dotlocal** - Hidden directory in home (default)
5. **Cloud storage** - Auto-discovered locations:
   - `~/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal` (iCloud)
   - `~/Dropbox/Dotlocal`
   - `~/Google Drive/Dotlocal`
   - `~/OneDrive/Dotlocal`
   - `/Volumes/*/Dotlocal` (Network drives)

**✅ Recent Fix**: Resolved critical bootstrap bug where debug output contaminated command substitution, causing filesystem corruption. The auto-discovery system now provides clean output and reliable symlink creation.

### 3. Symlink Override Mechanism

When you run `dots relink`:
1. Public configs create initial symlinks
2. Local configs **completely replace** matching public ones
3. You get a mix of public defaults and personal overrides

## Quick Start

### Setup Local Overrides

```bash
# Option 1: Use ~/.dotlocal (already done!)
mkdir -p ~/.dotlocal
# Add your configs with .symlink extension

# Option 2: Use cloud storage
ln -s ~/iCloud/Dotlocal ~/.dotfiles/local
# Edit dotfiles.conf to set LOCAL_PATH

# Option 3: Use a custom location
echo "LOCAL_PATH='/path/to/configs'" >> ~/.dotfiles/dotfiles.conf
```

### Apply Local Overrides

```bash
# Check current configuration
dots status

# Apply local overrides (they win!)
dots relink

# Preview changes without applying
dots relink --dry-run
```

## Commands

### `dots status`
Shows the current dotfiles configuration including:
- Dotfiles root directory
- Local configuration directory and type
- Current symlink status
- Active overrides

Options:
- `-s, --symlinks` - Show all managed symlinks
- `-v, --verbose` - Show detailed information

### `dots relink`
Recreates all symlinks with local precedence. Local configurations always override public ones.

Options:
- `--dry-run` - Preview changes without applying
- `--force` - Force overwrite existing files
- `--clean` - Clean broken symlinks first

### `dots repair-infrastructure`
Validates and repairs infrastructure symlinks in dotlocal. These symlinks provide access to shared infrastructure and documentation.

Options:
- `-p, --path PATH` - Specify dotlocal path (auto-discovered if not provided)
- `-q, --quiet` - Suppress verbose output
- `-h, --help` - Show help message

What it repairs:
- Missing infrastructure symlinks
- Broken symlinks (pointing to non-existent targets)
- Incorrect symlinks (pointing to wrong locations)
- Conflicting non-symlinks (backs up and replaces)

## Configuration File

The `dotfiles.conf` file (optional) allows explicit configuration:

```bash
# Path to your local/private configuration folder
DOTLOCAL='$HOME/.dotlocal'

# Backup settings (optional)
BACKUP_PATH='/Volumes/Backup/Dotfiles'
AUTO_SNAPSHOT='true'
```

## Examples

### Example 1: Override Shell Configuration

Public (`~/.dotfiles/shell/zshrc.symlink`):
```bash
# Basic template with sensible defaults
export EDITOR=vim
alias ll='ls -la'
```

Local (`~/.dotlocal/shell/zshrc.symlink`):
```bash
# Your personalized configuration
export EDITOR=nvim
alias ll='exa -la'
# Your custom functions, paths, etc.
```

Result: `~/.zshrc` → `~/.dotlocal/shell/zshrc.symlink` (local wins!)

### Example 2: Add Private SSH Keys

```bash
# Place in ~/.dotlocal/
ssh.symlink/
├── id_rsa
├── id_rsa.pub
├── config
└── known_hosts

# Run relink
dots relink

# Result: ~/.ssh → ~/.dotlocal/ssh.symlink
```

### Example 3: Store Secrets

Create `~/.dotlocal/localrc.symlink`:
```bash
export GITHUB_TOKEN="ghp_..."
export OPENAI_API_KEY="sk-..."
export AWS_ACCESS_KEY="..."
```

Your public shell config sources it:
```bash
# In public zshrc
[[ -f ~/.localrc ]] && source ~/.localrc
```

## Best Practices

### 1. Keep Public Minimal
- Only unopinionated defaults
- Well-documented templates
- No personal preferences
- No secrets or API keys

### 2. Organize Local Clearly
```
~/.dotlocal/
├── shell/          # Shell overrides
├── git/            # Git configuration
├── bin/            # Personal scripts
├── ssh.symlink/    # SSH keys
└── localrc.symlink # Secrets
```

### 3. Use Cloud Sync
```bash
# Link to iCloud
ln -s ~/Library/Mobile\ Documents/com~apple~CloudDocs/Dotlocal ~/.dotfiles/local

# Link to Dropbox
ln -s ~/Dropbox/Dotlocal ~/.dotfiles/local
```

### 4. Test Changes
```bash
# Always preview first
dots relink --dry-run

# Check status
dots status --symlinks

# Then apply
dots relink
```

## Security Considerations

1. **Never commit** `dotfiles.conf` if it contains sensitive paths
2. **Always check** `.gitignore` protects local folders
3. **Use ~/.localrc** for secrets, not version-controlled files
4. **Audit regularly** - ensure no secrets in public configs

## Troubleshooting

### Critical Fix Applied ✅
**Issue Resolved**: Fixed critical bootstrap bug where debug output contaminated command substitution, causing:
- Symlinks with debug text in paths instead of actual directories
- Garbage directories named after debug messages
- Complete filesystem corruption requiring manual recovery

**Solution**: All debug output in `core/lib/paths.sh` now redirects to stderr (`>&2`), ensuring command substitution returns clean paths only.

### Local configs not applying?
```bash
# Check configuration and auto-discovery
dots status --verbose           # See full discovery process

# Verify local path exists
ls -la ~/.dotlocal

# Test the discovery system
bash -c 'source ~/.dotfiles/core/lib/paths.sh && resolve_local_path'

# Force relink with clean symlinks
dots relink --clean --force
```

### Broken or corrupted symlinks?
```bash
# Clean up broken symlinks and recreate
dots relink --clean

# Check for corrupted paths (should show clean directories only)
ls -la ~ | grep -E "›|Starting|discovery"

# Manual cleanup if needed
find ~ -maxdepth 1 -type l ! -exec test -e {} \; -delete
```

### Bootstrap recovery after corruption?
```bash
# Safe recovery steps
cd ~/.dotfiles
git status                      # Check repository health
dots bootstrap --force         # Recreate with fixed bootstrap
dots status --verbose          # Verify clean discovery
```

### Want to see what's managed?
```bash
# Show all symlinks and discovery process
dots status --symlinks
dots status --verbose          # Show auto-discovery details
```

### Debugging auto-discovery
```bash
# Test discovery system manually
bash -c 'source ~/.dotfiles/core/lib/paths.sh && resolve_local_path'

# Should return clean path only, debug info goes to stderr
# If you see "› Starting..." mixed with the path, the bug still exists
```

## Architecture Details

The implementation consists of:

1. **core/lib/paths.sh** - Path resolution, environment setup, and configuration loading
2. **core/lib/symlink.sh** - Three-Tier Symlink Architecture with single source of truth
3. **core/lib/common.sh** - Shared utilities and messaging functions
4. **core/commands/relink** - Recreate all symlinks with local precedence
5. **core/commands/status** - Show configuration and status

### Symlink Architecture Implementation

The dotlocal system leverages the Three-Tier Symlink Architecture to ensure "local always wins":

**Layer 1: Two-Phase Precedence System**
- `create_all_symlinks_with_precedence()` orchestrates the entire process
- Phase 1: Creates public configuration symlinks
- Phase 2: Overrides with local configurations (local always wins)
- Used by `dots relink` to maintain precedence

**Layer 2: Infrastructure Integration**
- `create_infrastructure_symlink()` creates the 6 essential dotlocal infrastructure symlinks
- Handles: core→~/.dotfiles/core, docs→~/.dotfiles/docs, etc.
- Allows intentional infrastructure sharing between public and private repos
- Used by `setup_dotlocal_infrastructure()` for automated infrastructure management

**Layer 3: Single Source of Truth**
- `_create_symlink_raw()` is the ONLY function allowed to call `ln -s`
- Ensures consistent error handling across all dotlocal operations
- Provides command substitution safety (critical for path discovery functions)
- Centralized maintenance point for all symlink behavior

The system is designed to be:
- **Simple** - Just symlinks and naming conventions
- **Predictable** - Local always wins
- **Flexible** - Multiple ways to configure
- **Robust** - Handles missing dependencies gracefully

## Migration Guide

If you're migrating from the old system:

1. **Move private configs** to `~/.dotlocal/`
2. **Add .symlink extension** to files that should be symlinked
3. **Run `dots relink`** to apply changes
4. **Remove old symlinks** that are now managed

The system is backwards compatible - your existing setup continues to work while you migrate.

## Complete Installation Instructions

### Fresh Install on New Machine

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# 2. Create your local configuration directory
mkdir -p ~/.dotlocal

# 3. Optional: Configure LOCAL_PATH if not using ~/.dotlocal
echo "LOCAL_PATH='/path/to/your/local'" >> dotfiles.conf

# 4. Optional: Create symlink for easier navigation
ln -s ~/.dotlocal ~/.dotfiles/local

# 5. Run bootstrap to set up everything
./core/dots bootstrap

# 6. Apply local overrides
./core/dots relink
```

### Migrating Existing Dotfiles

```bash
# 1. Back up existing configs
mkdir -p ~/.dotlocal-backup
cp -r ~/.ssh ~/.dotlocal-backup/
cp ~/.gitconfig ~/.dotlocal-backup/
cp ~/.zshrc ~/.dotlocal-backup/

# 2. Move private configs to local
mkdir -p ~/.dotlocal/{shell,git,ssh.symlink}
mv ~/.ssh/* ~/.dotlocal/ssh.symlink/
mv ~/.localrc ~/.dotlocal/localrc.symlink

# 3. Apply the new system
cd ~/.dotfiles
./core/dots relink --force
```

### Cloud Storage Setup

```bash
# For iCloud
ln -s ~/Library/Mobile\ Documents/com~apple~CloudDocs/Dotlocal ~/.dotfiles/local
echo "LOCAL_PATH='$HOME/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal'" >> ~/.dotfiles/dotfiles.conf

# For Dropbox
ln -s ~/Dropbox/Dotlocal ~/.dotfiles/local
echo "LOCAL_PATH='$HOME/Dropbox/Dotlocal'" >> ~/.dotfiles/dotfiles.conf

# Apply changes
dots relink
```

## Testing Checklist

### Core Functionality Tests

```bash
# 1. Test Path Resolution
# Expected: Shows all 4 precedence levels correctly
bash -c 'source ~/.dotfiles/core/lib/paths.sh && resolve_local_path && echo "Type: $(get_local_path_type)"'

# 2. Test Status Command
# Expected: Shows configuration, local path, and symlink status
dots status
dots status --verbose
dots status --symlinks

# 3. Test Dry Run
# Expected: Shows what would change without making changes
dots relink --dry-run

# 4. Test Force Relink
# Expected: Recreates all symlinks with local precedence
dots relink --force

# 5. Test Clean Operation
# Expected: Removes broken symlinks then relinks
dots relink --clean
```

### Precedence Tests

```bash
# Test 1: Config file precedence (highest)
echo "LOCAL_PATH='/tmp/test-local'" >> ~/.dotfiles/dotfiles.conf
dots status  # Should show /tmp/test-local
rm ~/.dotfiles/dotfiles.conf

# Test 2: Symlink precedence
ln -sfn /tmp/test-local ~/.dotfiles/local
dots status  # Should show symlink to /tmp/test-local
rm ~/.dotfiles/local

# Test 3: Directory precedence
mkdir -p ~/.dotfiles/local
dots status  # Should show directory
rmdir ~/.dotfiles/local

# Test 4: Hidden directory precedence (lowest)
mkdir -p ~/.dotlocal
dots status  # Should show ~/.dotlocal
```

### Override Tests

```bash
# Test public-only config
echo "# Public version" > ~/.dotfiles/test.symlink
dots relink
cat ~/.test  # Should show "# Public version"

# Test local override
mkdir -p ~/.dotlocal
echo "# Local version" > ~/.dotlocal/test.symlink
dots relink
cat ~/.test  # Should show "# Local version"

# Clean up
rm ~/.test ~/.dotfiles/test.symlink ~/.dotlocal/test.symlink
```

### Integration Tests

```bash
# Test 1: Bootstrap compatibility
./core/dots bootstrap  # Should work with dotlocal system

# Test 2: Multiple symlink types
mkdir -p ~/.dotlocal/subdir.symlink
touch ~/.dotlocal/file.symlink
dots relink
ls -la ~/.subdir  # Should be symlinked directory
ls -la ~/.file    # Should be symlinked file

# Test 3: Broken symlink handling
ln -s /nonexistent ~/.broken
dots relink --clean  # Should remove ~/.broken

# Test 4: Git ignore protection
cd ~/.dotfiles
git status  # Should NOT show 'local' or 'dotfiles.conf'
```

### Edge Case Tests

```bash
# Test with no local directory
rm -rf ~/.dotlocal ~/.dotfiles/local
dots status  # Should show "Not configured"
dots relink  # Should use public configs only

# Test with missing target
echo "LOCAL_PATH='/nonexistent'" > ~/.dotfiles/dotfiles.conf
dots status  # Should show "Configured but missing"

# Test with circular symlink
ln -sfn ~/.dotfiles/local ~/.dotfiles/local
dots status  # Should handle gracefully

# Test with permission issues
mkdir -p /tmp/readonly-local
chmod 000 /tmp/readonly-local
echo "LOCAL_PATH='/tmp/readonly-local'" > ~/.dotfiles/dotfiles.conf
dots status  # Should handle permission error
chmod 755 /tmp/readonly-local
rm -rf /tmp/readonly-local
```

### Performance Tests

```bash
# Test with many symlinks
for i in {1..100}; do touch ~/.dotfiles/test$i.symlink; done
time dots relink --dry-run  # Should complete quickly
rm ~/.dotfiles/test*.symlink

# Test with deep directory structure
mkdir -p ~/.dotlocal/a/b/c/d/e.symlink
dots relink  # Should handle nested structures
```

## Core Library Organization

### Path Resolution (core/lib/paths.sh)

The `paths.sh` library is the heart of the dotlocal system, providing:

1. **Configuration Loading** - Loads `dotfiles.conf` for user settings
2. **Path Resolution** - 4-level precedence system for finding local directory
3. **Environment Setup** - Exports DOTLOCAL_DIR and backup settings
4. **Helper Functions**:
   - `resolve_local_path()` - Find local directory with precedence
   - `has_local_directory()` - Check if local exists
   - `get_local_path_type()` - Describe how local was found
   - `get_local_status()` - Report local directory status
   - `initialize_dotlocal_dir()` - Set up DOTLOCAL_DIR environment

### Symlink Management (core/lib/symlink.sh)

Handles the two-phase symlink creation ensuring local always wins:
- Phase 1: Create symlinks from public configs
- Phase 2: Override with local configs
- Includes cleanup, dry-run, and listing functions

### Common Utilities (core/lib/common.sh)

Provides shared functions used across all commands:
- Output functions (info, success, warning, error)
- Symlink utilities
- Directory helpers
- Topic discovery functions

## Summary

The dotlocal system provides a clean, elegant solution to the classic dotfiles problem: how to share useful configurations while protecting personal data. With its "local always wins" philosophy and zero-configuration design, it "just works" while adapting to your needs.

Whether you use cloud storage, local directories, or external drives, your private configurations remain private while your public templates help others. The system grows with you from simple configs to complex multi-machine setups.

**Remember:** Local always wins. Your configs, your control.

## Quick Reference

### Essential Commands
```bash
# Check system status
dots status                    # Basic status
dots status --verbose         # Detailed information  
dots status --symlinks        # Show all managed symlinks

# Apply configuration changes
dots relink                    # Apply local overrides
dots relink --dry-run          # Preview changes
dots relink --force            # Force overwrite conflicts
dots relink --clean            # Clean broken symlinks first

# Initial setup
dots bootstrap                 # First-time setup
dots bootstrap --install      # Setup + full installation
```

### Directory Structure
```bash
~/.dotfiles/                   # Public configurations (git repo)
├── topic/config.symlink      # Public template
└── .dotlocal -> ~/.dotlocal  # Symlink to private configs

~/.dotlocal/                   # Private configurations (local only)
├── topic/config.symlink      # Private override (WINS!)
├── ssh.symlink/              # SSH keys and config
└── localrc.symlink           # Secrets and API keys
```

### Precedence Order (Local Always Wins)
1. **dotfiles.conf** - Explicit configuration (highest priority)
2. **~/.dotfiles/.dotlocal** - Symlink to your local folder
3. **~/.dotfiles/.dotlocal** - Regular directory
4. **~/.dotlocal** - Hidden directory in home (default)

### Configuration Variables
```bash
# In dotfiles.conf
DOTLOCAL='/path/to/private/config'    # Where your private configs live
BACKUP_PATH='/path/to/backup'         # Backup location
AUTO_SNAPSHOT='true'                  # Enable automatic snapshots
```

### Common Patterns
```bash
# Override public shell config
echo "export EDITOR=nvim" > ~/.dotlocal/shell/zshrc.symlink
dots relink

# Add private SSH keys
mkdir -p ~/.dotlocal/ssh.symlink
cp ~/Downloads/id_rsa ~/.dotlocal/ssh.symlink/
dots relink

# Store secrets safely
echo "export API_KEY='secret'" > ~/.dotlocal/localrc.symlink
dots relink
```

### Troubleshooting Quick Fixes
```bash
# Local configs not applying?
dots status                    # Check configuration
dots relink --force           # Force application

# Broken symlinks?
dots relink --clean           # Clean and recreate

# Missing local directory?
mkdir -p ~/.dotlocal          # Create default location
dots relink                   # Apply changes

# Permission issues?
chmod -R 755 ~/.dotlocal      # Fix permissions
dots relink                   # Retry
```

### Cloud Storage Setup
```bash
# iCloud Drive
ln -s ~/Library/Mobile\ Documents/com~apple~CloudDocs/Dotlocal ~/.dotfiles/.dotlocal

# Dropbox  
ln -s ~/Dropbox/Dotlocal ~/.dotfiles/.dotlocal

# Custom location
echo "DOTLOCAL='/path/to/cloud/storage'" >> ~/.dotfiles/dotfiles.conf
```

### Testing Commands
```bash
# Validate system health
dots status --verbose

# Test configuration loading
zsh -n ~/.zshrc

# Check for conflicts
dots relink --dry-run

# Verify precedence
dots status | grep -A 5 "Local Configuration"
```

### File Types Reference
- **`.symlink`** files → Symlinked to `$HOME` (extension removed)
- **`path.zsh`** → PATH setup (loaded first)
- **`*.zsh`** → General configuration (loaded second)  
- **`completion.zsh`** → Tab completions (loaded last)
- **`install.sh`** → Installation scripts (run during setup)

### Key Principles
1. **Local Always Wins** - Private configs completely override public ones
2. **Zero Configuration** - Works out of the box with sensible defaults
3. **Cloud Sync Compatible** - Store private configs anywhere
4. **Defensive Programming** - Graceful handling of missing dependencies
5. **Progressive Enhancement** - Start simple, add complexity as needed

---

*For complete documentation, see the full sections above or visit the [Documentation Hub](README.md)*