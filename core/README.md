# Core - The Microdots Engine

**⚠️ This directory is the heart of the Microdots system. Do not modify unless you know what you're doing!**

## Purpose

The core directory contains the **infrastructure** that makes Microdots work. It is intentionally:
- **Unopinionated** - No user preferences
- **Pristine** - Only system mechanics
- **Self-contained** - Everything needed to manage microdots

## What's Here

### Commands (`commands/`)
The implementation of all `dots` subcommands:
- `bootstrap` - Initial system setup
- `install` - Run topic installers
- `status` - System health check
- `relink` - Symlink management
- `maintenance` - System updates
- `help` - Documentation

### Libraries (`lib/`)
**Intentional Shared Infrastructure** - These libraries provide consistent functionality across all microdots:
- `ui.sh` - Consistent terminal output formatting
- `common.sh` - Shared utilities and functions
- `validate-config.sh` - Configuration validation
- `symlink.sh` - Symlink management utilities

**Note:** The coupling between core libraries (e.g., common.sh sourcing ui.sh) is intentional. This shared infrastructure ensures consistent behavior across the entire Microdots system while individual microdots remain functionally independent.

## Philosophy

**Core is about HOW, not WHAT:**
- HOW to load microdots ✅
- HOW to create symlinks ✅
- HOW to run installers ✅
- WHAT packages to install ❌
- WHAT paths to set ❌
- WHAT aliases to use ❌

## Do NOT Add Here

- User PATH configurations (use local microdots)
- Personal preferences (use local microdots)
- Tool installations (use topic microdots)
- Aliases or functions (use topic microdots)

## Modifying Core

If you must modify core:
1. Understand the loading orchestration
2. Test thoroughly with `tests/run_integration_tests.sh`
3. Ensure changes are unopinionated
4. Document any new patterns

## The Prime Directive

**Core must work for everyone, forcing opinions on no one.**

It provides the mechanism for configuration without dictating the configuration itself.