# Dotlocal System Documentation

## Overview

This dotfiles repository implements a **dotlocal system** that elegantly separates public, shareable configurations from private, personal settings. The system ensures that local configurations **always win** over public ones through a sophisticated precedence mechanism.

## Key Features

- **Complete separation** of public templates and private configurations
- **Local always wins** - your personal configs override public defaults
- **Zero configuration required** - works out of the box
- **Cloud sync compatible** - store your private configs in iCloud, Dropbox, etc.
- **Progressive enhancement** - start simple, add complexity as needed

## How It Works

### 1. Two-Layer Configuration

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

### 2. Precedence System

The system checks for local configurations in this order:
1. **dotfiles.conf** - Explicit configuration (highest priority)
2. **~/.dotfiles/local** - Symlink to your local folder
3. **~/.dotfiles/local** - Regular directory
4. **~/.dotlocal** - Hidden directory in home

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

## Configuration File

The `dotfiles.conf` file (optional) allows explicit configuration:

```bash
# Path to your local/private configuration folder
LOCAL_PATH='/Users/username/.dotlocal'

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

### Local configs not applying?
```bash
# Check configuration
dots status

# Verify local path exists
ls -la ~/.dotlocal

# Force relink
dots relink --force
```

### Broken symlinks?
```bash
# Clean and relink
dots relink --clean
```

### Want to see what's managed?
```bash
# Show all symlinks
dots status --symlinks
```

## Architecture Details

The implementation consists of:

1. **core/lib/paths.sh** - Path resolution, environment setup, and configuration loading
2. **core/lib/symlink.sh** - Two-phase symlink creation with precedence
3. **core/lib/common.sh** - Shared utilities and messaging functions
4. **core/commands/relink** - Recreate all symlinks with local precedence
5. **core/commands/status** - Show configuration and status

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