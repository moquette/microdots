# Infrastructure System Documentation

---
**Document**: INFRASTRUCTURE.md
**Last Updated**: 2025-09-13
**Version**: 1.0
**Related Documentation**:
- [Documentation Hub](README.md) - Documentation navigation
- [Main Architecture Guide](../MICRODOTS.md) - Architecture principles
- [Technical Implementation](IMPLEMENTATION.md) - System internals
- [Dotlocal System](LOCAL_OVERRIDES.md) - Private configuration system
- [System Compliance](COMPLIANCE.md) - Compliance validation
---

## Table of Contents

- [Overview](#overview)
- [Infrastructure Symlinks System](#infrastructure-symlinks-system)
- [5-Level Auto-Discovery System](#5-level-auto-discovery-system)
- [Infrastructure Functions](#infrastructure-functions)
- [Critical Bug Fixes](#critical-bug-fixes)
- [Bootstrap Enhancements](#bootstrap-enhancements)
- [New Commands](#new-commands)
- [Development Guidelines](#development-guidelines)
- [Troubleshooting](#troubleshooting)
- [Recovery Procedures](#recovery-procedures)
- [Best Practices](#best-practices)

## Overview

The infrastructure system provides the foundational mechanisms that enable the Microdots architecture to function as a distributed configuration management system. This document covers the comprehensive infrastructure enhancements implemented to ensure zero-configuration setup, automatic discovery, and robust recovery mechanisms.

## Infrastructure Symlinks System

### What Are Infrastructure Symlinks?

Infrastructure symlinks are a set of **6 critical symlinks** created in the dotlocal directory that provide access to shared infrastructure components and documentation. Unlike functional dependencies between microdots (which are forbidden), these symlinks provide infrastructure access that enables proper operation.

### The 6 Infrastructure Symlinks

```bash
~/.dotlocal/
├── core → ~/.dotfiles/core                    # UI library and utilities
├── docs → ~/.dotfiles/docs                    # Documentation directory
├── MICRODOTS.md → ~/.dotfiles/MICRODOTS.md    # Architecture guide
├── CLAUDE.md → ~/.dotfiles/CLAUDE.md          # AI agent configuration
├── TASKS.md → ~/.dotfiles/TASKS.md            # Project tasks
└── COMPLIANCE.md → ~/.dotfiles/docs/COMPLIANCE.md  # Compliance documentation
```

### Architectural Justification

These symlinks are **acceptable cross-repository dependencies** because they provide:

1. **Infrastructure Access** - Not functional coupling
2. **Documentation Access** - Essential for understanding the system
3. **Tool Access** - UI library for consistent output formatting
4. **Development Support** - Access to shared utilities

They do **NOT** violate the zero-coupling principle because:

- They provide infrastructure, not functionality
- Removing them doesn't break microdot functionality
- They enable proper tooling and documentation access
- They're automatically managed and repaired

### When Infrastructure Symlinks Are Created

Infrastructure symlinks are automatically created during:

1. **Bootstrap process** - Initial system setup
2. **Dotlocal resolution** - When dotlocal path is resolved
3. **Infrastructure repair** - When corruption is detected
4. **Manual repair** - Via `dots repair-infrastructure` command

## 5-Level Auto-Discovery System

### Discovery Precedence

The auto-discovery system uses a **5-level precedence hierarchy** to find dotlocal configuration:

```bash
# Level 1: Explicit Configuration (Highest Priority)
# Check dotfiles.conf for DOTLOCAL variable
if [[ -n "${DOTLOCAL:-}" ]]; then
    # Use configured path
fi

# Level 2: Existing Symlink
# Check for ~/.dotfiles/.dotlocal symlink
if [[ -L "$dotfiles_root/.dotlocal" ]]; then
    # Use symlink target
fi

# Level 3: Existing Directory
# Check for ~/.dotfiles/.dotlocal directory
if [[ -d "$dotfiles_root/.dotlocal" ]]; then
    # Use directory
fi

# Level 4: Standard Location
# Check for ~/.dotlocal (default)
if [[ -d "$HOME/.dotlocal" ]]; then
    # Use standard location
fi

# Level 5: Cloud Storage Auto-Discovery (Lowest Priority)
# Scan for cloud storage locations:
# - iCloud Drive
# - Dropbox
# - Google Drive
# - OneDrive
# - Network volumes
```

### Zero-Configuration Benefits

This system enables **zero-configuration setup**:

- Fresh installs work immediately
- No manual configuration required
- Automatic cloud storage detection
- Graceful fallback to defaults
- Production-ready reliability

### Critical Command Substitution Safety

⚠️ **CRITICAL BUG FIX**: The discovery function is used in command substitution (`$(discover_dotlocal_path)`), which means **ALL output must go to stderr**, not stdout. Only the result path goes to stdout.

**Before (Broken)**:
```bash
info "Starting discovery..."  # Goes to stdout - BREAKS command substitution
echo "$discovered_path"       # Result contaminated with debug info
```

**After (Fixed)**:
```bash
info "Starting discovery..." >&2  # Goes to stderr - safe
echo "$discovered_path"           # Clean result for command substitution
```

This bug caused **massive system corruption** where debug output was interpreted as paths, breaking symlink creation.

## Infrastructure Functions

### Core Infrastructure Functions

The system provides three critical infrastructure functions:

#### 1. `setup_dotlocal_infrastructure()`

**Purpose**: Creates and manages infrastructure symlinks
**Usage**: `setup_dotlocal_infrastructure "$dotlocal_path" "$dotfiles_root" "$force" "$verbose"`

```bash
# Creates all 6 infrastructure symlinks
# Handles updates and force recreation
# Validates targets before creating symlinks
# Provides detailed feedback
```

**Features**:
- Enhanced target validation (checks readability)
- Force recreation capability
- Detailed logging and feedback
- Automatic recovery from broken symlinks

#### 2. `validate_infrastructure_symlinks()`

**Purpose**: Health checking for all infrastructure symlinks
**Usage**: `validate_infrastructure_symlinks "$dotlocal_path" "$dotfiles_root" "$verbose"`

```bash
# Returns: 0 if all healthy, >0 for number of issues found
issues=0
validate_infrastructure_symlinks "$dotlocal_path" "$dotfiles_root" "true" || issues=$?

if [[ $issues -eq 0 ]]; then
    echo "All infrastructure healthy"
else
    echo "Found $issues issue(s)"
fi
```

**Validation Checks**:
- Symlink existence
- Symlink validity (not broken)
- Correct target verification
- Type validation (symlink vs file/directory)

#### 3. `repair_infrastructure()`

**Purpose**: Automatic repair of corrupted infrastructure
**Usage**: `repair_infrastructure "$dotlocal_path" "$dotfiles_root" "$verbose"`

```bash
# Complete infrastructure repair workflow:
# 1. Validate current state
# 2. Remove broken/incorrect symlinks
# 3. Backup non-symlink conflicts
# 4. Force recreate all infrastructure
# 5. Validate repair success
```

**Repair Actions**:
- Removes broken symlinks
- Fixes incorrect targets
- Backs up conflicting files
- Force recreates all infrastructure
- Validates repair success

### Supporting Functions

#### Path Resolution Functions

- `discover_dotlocal_path()` - Core 5-level discovery
- `resolve_dotlocal_path()` - Discovery + setup + infrastructure creation
- `get_dotlocal_discovery_method()` - Returns how discovery succeeded
- `clear_dotlocal_cache()` - Clears discovery cache (for testing)

#### Validation Functions

- `validate_dotlocal_path()` - Checks path exists and is accessible
- `get_dotlocal_status()` - Returns JSON status information
- `get_dotlocal_type()` - Returns configuration type (explicit/symlink/directory/standard)

#### Configuration Functions

- `load_dotfiles_config()` - Loads dotfiles.conf safely
- `create_dotfiles_config()` - Creates config for auto-discovered cloud locations

## Critical Bug Fixes

### 1. Command Substitution Contamination (CATASTROPHIC)

**Problem**: Debug output from `discover_dotlocal_path()` was contaminating command substitution results, causing system-wide corruption.

```bash
# BROKEN: Debug output contaminates result
discovered_path=$(discover_dotlocal_path)
# Result: "Starting discovery...\n/path/to/dotlocal"
# System interprets debug text as path - CATASTROPHIC
```

**Solution**: All debug output redirected to stderr (`>&2`):

```bash
# FIXED: Clean command substitution
[[ "$verbose" == "true" ]] && info "Starting discovery..." >&2
echo "$discovered_path"  # Only result to stdout
```

**Impact**: This fix prevents system corruption and enables reliable automated bootstrap.

### 2. Bootstrap Integration Issues

**Problem**: Bootstrap wasn't properly integrated with auto-discovery system.

**Solution**: Complete bootstrap enhancement:
- Integrated 5-level auto-discovery
- Automatic dotlocal infrastructure setup
- Proper .dotlocal symlink creation
- Infrastructure validation and repair

### 3. Missing Error Recovery

**Problem**: No mechanism to recover from infrastructure corruption.

**Solution**: Comprehensive repair system:
- Automatic validation on every discovery
- Built-in repair functions
- New `dots repair-infrastructure` command
- Complete recovery workflows

## Bootstrap Enhancements

### New Bootstrap Flow

The enhanced bootstrap process now includes:

```bash
# 1. Standard Setup
setup_gitconfig()

# 2. AUTO-DISCOVERY AND INFRASTRUCTURE SETUP
setup_dotlocal_symlink()
# - Runs 5-level auto-discovery
# - Creates/updates .dotlocal symlink
# - Sets up all infrastructure symlinks
# - Exports DISCOVERED_DOTLOCAL_PATH

# 3. Symlink Creation (uses discovered path)
install_dotfiles()

# 4. Package Manager Setup
install_homebrew()

# 5. Optional Full Installation
if [[ "$run_install" == "true" ]]; then
    # Run all topic installers
fi
```

### Zero-Configuration Achievement

The bootstrap enhancements achieve **true zero-configuration**:

- Works on fresh systems without any setup
- Automatically discovers existing configurations
- Creates infrastructure if missing
- Handles cloud storage locations
- Provides immediate functionality

## New Commands

### `dots repair-infrastructure`

**Purpose**: Validate and repair infrastructure symlinks

#### Usage

```bash
# Basic repair (auto-discovers dotlocal path)
dots repair-infrastructure

# Specify dotlocal path
dots repair-infrastructure --path ~/.dotlocal

# Quiet mode (suppress verbose output)
dots repair-infrastructure --quiet

# Help
dots repair-infrastructure --help
```

#### What It Does

1. **Discovery**: Finds dotlocal path (or uses provided path)
2. **Validation**: Checks all 6 infrastructure symlinks
3. **Reporting**: Shows issues found
4. **Repair**: Removes broken/incorrect symlinks
5. **Backup**: Saves conflicting non-symlinks
6. **Recreation**: Force recreates all infrastructure
7. **Validation**: Verifies repair success

#### Output Example

```bash
🔧 Infrastructure Repair

🔧 Infrastructure Repair Mode
› Repairing infrastructure in: /Users/user/.dotlocal
⚠ Found 3 issue(s) - starting repair...
› Removing broken symlink: docs
› Removing incorrect symlink: CLAUDE.md
⟳ Recreating infrastructure symlinks...
✓ Created infrastructure symlink: core → /Users/user/.dotfiles/core
✓ Updated infrastructure symlink: docs → /Users/user/.dotfiles/docs
✓ Updated infrastructure symlink: CLAUDE.md → /Users/user/.dotfiles/CLAUDE.md
⟳ Validating repair...
✅ Infrastructure repair complete - all symlinks healthy

📊 Summary
✓ 1 successful operation
```

## Development Guidelines

### Command Substitution Safety

⚠️ **CRITICAL RULE**: Functions used in command substitution must not output to stdout except for the result.

```bash
# SAFE: All debug output to stderr
my_function() {
    local verbose="$1"
    [[ "$verbose" == "true" ]] && echo "Debug info" >&2  # Safe
    echo "$result"  # Only result to stdout
}

# Usage in command substitution
result=$(my_function "true")  # Clean result
```

### Infrastructure Dependency Rules

✅ **ACCEPTABLE**: Infrastructure symlinks for:
- UI library access (`core/lib/ui.sh`)
- Documentation access (`docs/`, `MICRODOTS.md`)
- Development tooling (`core/lib/common.sh`)

❌ **FORBIDDEN**: Functional dependencies:
- Cross-topic configuration dependencies
- Topic-to-topic functional coupling
- Shared state or configuration

### Error Handling Patterns

```bash
# Defensive programming for infrastructure
if ! validate_infrastructure_symlinks "$dotlocal_path" "$dotfiles_root" "false"; then
    warning "Infrastructure issues detected - attempting repair"
    if repair_infrastructure "$dotlocal_path" "$dotfiles_root" "true"; then
        success "Infrastructure repaired successfully"
    else
        error "Failed to repair infrastructure - manual intervention required"
        exit 1
    fi
fi
```

### Testing Infrastructure

```bash
# Test infrastructure functions
source "$DOTFILES_ROOT/core/lib/paths.sh"

# Test discovery
discovered_path=$(discover_dotlocal_path "$DOTFILES_ROOT" "true")
echo "Discovered: $discovered_path"

# Test validation
if validate_infrastructure_symlinks "$discovered_path" "$DOTFILES_ROOT" "true"; then
    echo "Infrastructure healthy"
else
    echo "Infrastructure needs repair"
fi

# Test repair
repair_infrastructure "$discovered_path" "$DOTFILES_ROOT" "true"
```

## Troubleshooting

### Common Infrastructure Issues

#### Issue: Discovery Returns Empty Path

```bash
# Debug discovery
discovered_path=$(discover_dotlocal_path "$DOTFILES_ROOT" "true")
echo "Result: '$discovered_path'"

# Check discovery method
method=$(get_dotlocal_discovery_method)
echo "Method: $method"
```

**Solutions**:
1. Run `dots bootstrap` to set up default location
2. Create explicit config: `echo 'DOTLOCAL="$HOME/.dotlocal"' >> ~/.dotfiles/dotfiles.conf`
3. Create symlink: `ln -s ~/.dotlocal ~/.dotfiles/.dotlocal`

#### Issue: Infrastructure Symlinks Missing/Broken

```bash
# Check infrastructure health
if ! validate_infrastructure_symlinks ~/.dotlocal ~/.dotfiles true; then
    echo "Infrastructure issues found"
fi
```

**Solutions**:
1. Automatic: `dots repair-infrastructure`
2. Manual: `setup_dotlocal_infrastructure ~/.dotlocal ~/.dotfiles true true`
3. Bootstrap: `dots bootstrap` (recreates everything)

#### Issue: Command Substitution Returning Garbage

```bash
# Check for debug output contamination
result=$(discover_dotlocal_path "$DOTFILES_ROOT" "true" 2>/dev/null)
debug_output=$(discover_dotlocal_path "$DOTFILES_ROOT" "true" 2>&1 >/dev/null)

echo "Clean result: '$result'"
echo "Debug output: '$debug_output'"
```

**Solution**: Ensure all functions redirect debug output to stderr (`>&2`).

### Infrastructure Health Check

```bash
# Complete infrastructure health check
check_infrastructure_health() {
    local dotfiles_root="${1:-$HOME/.dotfiles}"

    echo "=== Infrastructure Health Check ==="

    # Check discovery
    local discovered_path=$(discover_dotlocal_path "$dotfiles_root" "false")
    if [[ -z "$discovered_path" ]]; then
        echo "❌ Discovery failed - no dotlocal path found"
        return 1
    fi
    echo "✅ Discovery successful: $discovered_path"

    # Check infrastructure
    local issues=0
    validate_infrastructure_symlinks "$discovered_path" "$dotfiles_root" "false" || issues=$?

    if [[ $issues -eq 0 ]]; then
        echo "✅ All infrastructure symlinks healthy"
    else
        echo "❌ Found $issues infrastructure issue(s)"
        echo "   Run: dots repair-infrastructure"
        return $issues
    fi

    echo "✅ Infrastructure system fully operational"
    return 0
}

# Run health check
check_infrastructure_health
```

## Recovery Procedures

### Complete System Recovery

If the infrastructure system is completely corrupted:

```bash
# 1. Clear all caches
source ~/.dotfiles/core/lib/paths.sh
clear_dotlocal_cache

# 2. Remove broken symlinks
rm -f ~/.dotfiles/.dotlocal

# 3. Run full bootstrap
~/.dotfiles/core/commands/bootstrap --install

# 4. Verify repair
dots status --verbose
dots repair-infrastructure
```

### Partial Recovery (Infrastructure Only)

If only infrastructure symlinks are corrupted:

```bash
# 1. Run targeted repair
dots repair-infrastructure --path ~/.dotlocal

# 2. Verify success
ls -la ~/.dotlocal/core ~/.dotlocal/docs

# 3. Test functionality
source ~/.dotlocal/core/lib/ui.sh
info "Infrastructure test"
```

### Emergency Manual Recovery

If automated recovery fails:

```bash
# 1. Find dotlocal directory
find ~ -name ".dotlocal" -type d 2>/dev/null
find ~ -name "Dotlocal" -type d 2>/dev/null

# 2. Manually create infrastructure symlinks
DOTLOCAL_PATH="/path/to/your/dotlocal"
DOTFILES_ROOT="$HOME/.dotfiles"

ln -sfn "$DOTFILES_ROOT/core" "$DOTLOCAL_PATH/core"
ln -sfn "$DOTFILES_ROOT/docs" "$DOTLOCAL_PATH/docs"
ln -sfn "$DOTFILES_ROOT/MICRODOTS.md" "$DOTLOCAL_PATH/MICRODOTS.md"
ln -sfn "$DOTFILES_ROOT/CLAUDE.md" "$DOTLOCAL_PATH/CLAUDE.md"
ln -sfn "$DOTFILES_ROOT/TASKS.md" "$DOTLOCAL_PATH/TASKS.md"
ln -sfn "$DOTFILES_ROOT/docs/COMPLIANCE.md" "$DOTLOCAL_PATH/COMPLIANCE.md"

# 3. Verify manually
ls -la "$DOTLOCAL_PATH"
```

## Best Practices

### Development Best Practices

1. **Always use stderr for debug output** in functions used in command substitution
2. **Test command substitution results** to ensure they're clean
3. **Use infrastructure validation** before critical operations
4. **Implement graceful degradation** when infrastructure is missing
5. **Document infrastructure dependencies** clearly

### Usage Best Practices

1. **Run `dots status --verbose`** periodically to check infrastructure health
2. **Use `dots repair-infrastructure`** at first sign of issues
3. **Keep dotlocal path consistent** across machines via dotfiles.conf
4. **Back up dotlocal directory** before major changes
5. **Test bootstrap process** on fresh systems

### Maintenance Best Practices

1. **Monitor infrastructure health** in regular maintenance
2. **Update documentation** when adding new infrastructure symlinks
3. **Test recovery procedures** periodically
4. **Keep infrastructure symlinks minimal** - only add what's essential
5. **Document architectural decisions** for future maintainers

---

*This infrastructure system enables the Microdots architecture to function as a truly distributed configuration management system with zero-configuration setup, automatic recovery, and bulletproof reliability.*