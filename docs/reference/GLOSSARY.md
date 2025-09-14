# Microdots Glossary & Reference Guide

A comprehensive reference for all terminology, commands, variables, and concepts used throughout the Microdots system.

---

## Table of Contents

- [Core Concepts](#core-concepts)
- [Environment Variables](#environment-variables)  
- [Commands Reference](#commands-reference)
- [File Types & Extensions](#file-types--extensions)
- [Directory Structure](#directory-structure)
- [Loading Stages](#loading-stages)
- [UI Functions](#ui-functions)
- [Testing Commands](#testing-commands)
- [Configuration Files](#configuration-files)
- [Error Codes](#error-codes)
- [Troubleshooting Patterns](#troubleshooting-patterns)
- [Cross-Reference Index](#cross-reference-index)

---

## Core Concepts

### **Microdot**
A self-contained configuration microservice that manages one specific tool or domain. Each microdot operates independently with zero coupling to other microdots.
- **File Reference**: [MICRODOTS.md](../MICRODOTS.md)
- **Implementation**: [IMPLEMENTATION.md](IMPLEMENTATION.md)

### **Topic**
Synonym for microdot. A directory containing configuration files, installation scripts, and shell integration for a specific tool or functional area.
- **Examples**: `git/`, `homebrew/`, `zsh/`, `claude/`

### **Dotlocal System**
A private configuration layer that allows local settings to override public configurations. Follows the principle "local always wins".
- **File Reference**: [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md)
- **Variable**: `$DOTLOCAL`

### **Self-Containment**
Architecture principle requiring each microdot to include all necessary functionality within its own directory, with no dependencies on other microdots.
- **Exception**: Core library infrastructure (`core/lib/`)

### **Defensive Programming**
Pattern of checking for dependencies and gracefully handling missing tools or configurations.
- **Pattern**: `if command -v tool >/dev/null 2>&1; then ... fi`

### **Hot Deployment**
Ability to add or remove microdots without system restart or reconfiguration.
- **Mechanism**: Filesystem-based discovery patterns

### **Three-Tier Symlink Architecture**
Hierarchical system for all symlink creation ensuring consistency and single source of truth.
- **Layer 1**: High-level orchestration functions (`create_all_symlinks_with_precedence`)
- **Layer 2**: Specialized domain-specific functions (infrastructure, bootstrap, application, command)
- **Layer 3**: Single source of truth (`_create_symlink_raw` - ONLY function with `ln -s`)
- **File Reference**: [IMPLEMENTATION.md](IMPLEMENTATION.md#symlink-architecture)

### **Single Source of Truth (Symlinks)**
Architectural principle where only `_create_symlink_raw()` is allowed to call `ln -s` directly.
- **Location**: `core/lib/symlink.sh` line 632
- **Purpose**: Ensures consistent error handling, logging, and command substitution safety
- **Rule**: ALL other symlink creation must use appropriate Layer 1 or Layer 2 functions
- **Violation**: Using direct `ln -s` calls bypasses architecture and is forbidden

### **_create_symlink_raw()**
The ONLY function in the entire codebase allowed to call `ln -s` directly.
- **Parameters**: `source`, `target`, `force`, `allow_existing`
- **Purpose**: Low-level symlink creation with unified error handling
- **Location**: `core/lib/symlink.sh` line 590
- **Critical Rule**: No other function may call `ln -s`

### **Symlink Specialized Functions (Layer 2)**
Domain-specific symlink creation functions that delegate to `_create_symlink_raw()`:

#### **create_infrastructure_symlink()**
Creates dotlocal infrastructure symlinks (core→~/.dotfiles/core, docs→~/.dotfiles/docs)
- **Usage**: Infrastructure sharing between public and private repos
- **Parameters**: `source`, `target`, `name`, `force`, `verbose`

#### **create_bootstrap_symlink()**
Minimal symlink creation for early bootstrap setup
- **Usage**: Initial system configuration during `dots bootstrap`
- **Parameters**: `source`, `target`, `name`, `skip_existing`

#### **create_application_symlink()**
Specialized for application-specific configurations (Claude Desktop, MCP configs)
- **Usage**: Application installers and complex configurations
- **Parameters**: `source`, `target`, `app_name`, `force`, `dry_run`, `verbose`

#### **create_command_symlink()**
Creates symlinks for command-line tools (bin/dots, executables)
- **Usage**: Command installation and PATH integration
- **Parameters**: `source`, `target`, `command_name`, `force`

---

## Environment Variables

### **Core System Variables**

#### `$DOTFILES_ROOT`
**Purpose**: Path to the main dotfiles directory
**Default**: `~/.dotfiles`
**Usage**: Used throughout system for path resolution
**Files**: All core scripts and configuration files

#### `$ZSH`
**Purpose**: Alias for `$DOTFILES_ROOT` (compatibility)
**Default**: Same as `$DOTFILES_ROOT`
**Usage**: Shell configuration and topic loading
**Files**: `zsh/zshrc.symlink`

#### `$DOTLOCAL`
**Purpose**: Path to private/local configuration directory
**Default**: Resolved via 4-level precedence system
**Priority Order**:
1. `dotfiles.conf` configuration
2. `~/.dotfiles/.dotlocal` symlink
3. `~/.dotfiles/.dotlocal` directory  
4. `~/.dotlocal` directory
**Files**: All core commands, [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md)

#### `$PROJECTS`
**Purpose**: Default directory for code projects
**Default**: `~/Code`
**Usage**: Development environment setup
**Files**: Various topic configurations

### **UI and Output Variables**

#### `$DEBUG`
**Purpose**: Enable debug output
**Values**: `true` or unset
**Usage**: `DEBUG=true dots command`
**Effect**: Shows detailed execution information

#### `$VERBOSE`
**Purpose**: Enable verbose output
**Values**: `true` or unset  
**Usage**: `VERBOSE=true dots status`
**Effect**: Shows additional detail in command output

#### `$NO_COLOR`
**Purpose**: Disable color output
**Values**: `1` or unset
**Usage**: `NO_COLOR=1 dots status`
**Effect**: Plain text output without ANSI colors

#### `$QUIET`
**Purpose**: Minimize output (errors only)
**Values**: `true` or unset
**Usage**: `QUIET=true dots install`
**Effect**: Only shows error messages

### **Configuration Variables**

#### `$BACKUP_PATH`
**Purpose**: Location for configuration backups
**Default**: Not set
**Config File**: `dotfiles.conf`
**Usage**: Automated backup operations

#### `$AUTO_SNAPSHOT`
**Purpose**: Enable automatic snapshots
**Values**: `true` or `false`
**Default**: `false`
**Config File**: `dotfiles.conf`

---

## Commands Reference

### **Core Commands (`dots`)**

#### `dots bootstrap [--install]`
**Purpose**: Initial system setup
**Actions**:
- Configures git user information
- Creates initial symlinks from `*.symlink` files
- Installs Homebrew (macOS)
- Optionally runs full installation
**Files**: `core/commands/bootstrap`
**Reference**: [IMPLEMENTATION.md](IMPLEMENTATION.md#installation-flow)

#### `dots status [options]`
**Purpose**: Display system configuration and status
**Options**:
- `-s, --symlinks`: Show all managed symlinks
- `-v, --verbose`: Show detailed information
**Output**: Configuration paths, symlink status, active overrides
**Files**: `core/commands/status`
**Reference**: [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md#commands)

#### `dots relink [options]`
**Purpose**: Recreate all symlinks with local precedence
**Options**:
- `--dry-run`: Preview changes without applying
- `--force`: Force overwrite existing files
- `--clean`: Remove broken symlinks first
**Principle**: Local configurations always override public ones
**Files**: `core/commands/relink`
**Reference**: [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md#commands)

#### `dots install`
**Purpose**: Run all topic installation scripts
**Actions**:
- Discovers all `install.sh` scripts
- Executes each installer in sequence
- Reports success/failure for each topic
**Files**: `core/commands/install`
**Reference**: [IMPLEMENTATION.md](IMPLEMENTATION.md#installation-flow)

#### `dots update`
**Purpose**: Update system and configurations
**Actions**:
- Pulls latest dotfiles changes
- Updates macOS settings (if applicable)
- Updates Homebrew packages
- Runs all topic installers
**Files**: `core/commands/update`

#### `dots maintenance`
**Purpose**: System maintenance and cleanup
**Actions**:
- Package updates
- Cache cleanup
- Health checks
- Optimization
**Files**: `core/commands/maintenance`

### **MCP Commands**

#### `mcp-setup-global`
**Purpose**: Configure MCP servers for Claude Code
**Actions**: Installs MCP servers to `~/.claude/.claude.json`
**Usage**: `mcp-setup-global`
**Files**: MCP installation scripts

#### `claude mcp list`
**Purpose**: List configured MCP servers
**Output**: Shows all configured servers and status
**Usage**: `claude mcp list`

#### `claude mcp add <name> <command> [options]`
**Purpose**: Add new MCP server
**Pattern**: `claude mcp add <server> npx --scope user -- -y <package>`
**Example**: `claude mcp add filesystem npx --scope user -- -y @mcp/server-filesystem`

### **Testing Commands**

#### `tests/run_integration_tests.sh`
**Purpose**: Run complete integration test suite
**Coverage**: 85 tests covering all system components
**Usage**: `./tests/run_integration_tests.sh`
**Output**: Pass/fail status for each test

#### `tests/unit/test_portability.sh`
**Purpose**: Check for hardcoded paths and usernames
**Usage**: `./tests/unit/test_portability.sh`
**Validates**: Cross-platform compatibility

#### `tests/run_all_tests.sh`
**Purpose**: Complete test suite execution
**Includes**: Unit tests, integration tests, portability checks
**Usage**: `./tests/run_all_tests.sh`

---

## File Types & Extensions

### **Configuration Files**

#### `*.symlink`
**Purpose**: Files/directories to symlink to `$HOME`
**Processing**: Extension removed during symlinking
**Examples**: 
- `gitconfig.symlink` → `~/.gitconfig`
- `ssh.symlink/` → `~/.ssh/`
**Location**: Any topic directory

#### `path.zsh`
**Purpose**: PATH and environment variable setup
**Loading**: Stage 1 (first)
**Pattern**: Defensive PATH additions
**Example**: `export PATH="/opt/homebrew/bin:$PATH"`

#### `*.zsh` (general)
**Purpose**: Shell configuration, aliases, functions
**Loading**: Stage 2 (after PATH setup)
**Excludes**: `path.zsh`, `completion.zsh`
**Pattern**: Tool configuration and integration

#### `completion.zsh`
**Purpose**: Tab completion definitions
**Loading**: Stage 4 (last, after compinit)
**Pattern**: Conditional completion loading
**Requirement**: Tool existence check

#### `install.sh`
**Purpose**: Dependency installation and setup
**Requirements**: Executable, idempotent
**Pattern**: Multi-platform, graceful failure
**Location**: Topic root or subtopic directories

### **Core System Files**

#### `dotfiles.conf`
**Purpose**: User configuration overrides
**Format**: Shell variable assignments
**Location**: `$DOTFILES_ROOT/dotfiles.conf`
**Variables**: `DOTLOCAL`, `BACKUP_PATH`, `AUTO_SNAPSHOT`

#### `README.md`
**Purpose**: Documentation (topic or system level)
**Format**: Markdown with standard sections
**Location**: Any directory
**Sections**: Overview, usage, configuration

---

## Directory Structure

### **Standard Topic Structure**
```
topic-name/
├── path.zsh          # PATH/environment setup
├── config.zsh        # Main configuration  
├── aliases.zsh       # Command aliases
├── functions.zsh     # Helper functions
├── completion.zsh    # Tab completions
├── *.symlink        # Config files to link
├── install.sh       # Installation script
├── README.md        # Documentation
└── lib/             # Internal libraries (optional)
```

### **Core Infrastructure**
```
core/
├── dots             # Main CLI router
├── commands/        # Core command implementations
├── lib/             # Shared libraries
│   ├── ui.sh       # UI formatting functions
│   ├── common.sh   # Shared utilities  
│   ├── paths.sh    # Path resolution
│   └── symlink.sh  # Symlink management
└── setup           # Initial system setup
```

### **Documentation Hierarchy**
```
/
├── README.md           # Project overview
├── MICRODOTS.md       # Architecture guide
├── CLAUDE.md          # AI agent configuration
└── docs/              # Reference documentation
    ├── README.md      # Documentation index
    ├── GLOSSARY.md    # This file
    ├── IMPLEMENTATION.md
    ├── LOCAL_OVERRIDES.md
    ├── UI_STYLE_GUIDE.md
    ├── COMPLIANCE.md
    └── MIGRATION_TO_DOTLOCAL.md
```

---

## Loading Stages

The shell initialization follows a strict 4-stage loading order:

### **Stage 1: PATH Setup**
**Files**: All `*/path.zsh` files
**Purpose**: Ensure tools are available in PATH
**Requirements**: Defensive programming, multiple location checks
**Example**: Tool installation path detection

### **Stage 2: Configuration Loading**  
**Files**: All `*.zsh` except `path.zsh` and `completion.zsh`
**Purpose**: Load aliases, functions, tool configuration
**Dependencies**: Stage 1 PATH must be complete
**Pattern**: Tool existence checks before configuration

### **Stage 3: Completion Initialization**
**Command**: `autoload -U compinit && compinit`
**Purpose**: Initialize zsh completion system
**Flags**: `-u` flag suppresses ownership warnings
**Location**: `zsh/zshrc.symlink`

### **Stage 4: Completion Loading**
**Files**: All `*/completion.zsh` files  
**Purpose**: Load command-specific completions
**Dependencies**: Stage 3 completion system must be initialized
**Pattern**: Conditional loading based on tool availability

---

## UI Functions

### **Message Types**

#### `header "text"`
**Purpose**: Major section headers
**Format**: Bold text with separator line
**Example**: `header "🔧 Installation"`

#### `subheader "text"`
**Purpose**: Subsection headers
**Format**: Emphasized text
**Example**: `subheader "Configuration"`

#### `info "text"`
**Purpose**: Informational messages
**Format**: `› text`
**Usage**: General status updates

#### `success "text"`
**Purpose**: Success messages
**Format**: `✓ text` (green)
**Usage**: Completed operations

#### `warning "text"`  
**Purpose**: Warning messages
**Format**: `⚠ text` (yellow)
**Usage**: Non-critical issues

#### `error "text"`
**Purpose**: Error messages
**Format**: `✗ text` (red, to stderr)
**Usage**: Failed operations

#### `progress "text"`
**Purpose**: Progress indicators
**Format**: `⟳ text` (cyan)
**Usage**: Ongoing operations

### **Display Functions**

#### `key_value "key" "value"`
**Purpose**: Configuration display
**Format**: `Key: Value`
**Usage**: System status information

#### `list_item "text"`
**Purpose**: List formatting
**Format**: `• text`
**Usage**: Bulleted lists

#### `status "component" "state"`
**Purpose**: Status indicators
**Format**: Component specific icons
**States**: `healthy`, `warning`, `error`, `active`

#### `summary "operation" success_count warning_count error_count`
**Purpose**: Operation summaries
**Format**: Standardized result reporting
**Usage**: End of command execution

---

## Testing Commands

### **Integration Tests**
```bash
# Run all 85 integration tests
./tests/run_integration_tests.sh

# Run specific test category
./tests/integration/test_topic_independence.sh
./tests/integration/test_loading_order.sh
./tests/integration/test_symlink_management.sh
```

### **Portability Tests**
```bash
# Check for hardcoded paths
./tests/unit/test_portability.sh

# Complete portability validation
./tests/unit/test_complete_portability.sh
```

### **System Validation**
```bash
# Validate configuration files
./core/lib/validate-config.sh

# Check system health
dots status --verbose

# Debug shell loading
ZSH=~/.dotfiles zsh -x -c 'source ~/.zshrc' 2>&1 | head -20
```

---

## Configuration Files

### **Global Configuration (`dotfiles.conf`)**
```bash
# Private configuration directory
DOTLOCAL='/path/to/private/config'

# Backup settings
BACKUP_PATH='/Volumes/Backup/Dotfiles'
AUTO_SNAPSHOT='true'
```

### **Git Configuration (`.gitconfig.local`)**
```ini
[user]
    name = Your Name
    email = your.email@example.com

[github]
    user = yourusername
```

### **Shell Secrets (`localrc.symlink`)**
```bash
export GITHUB_TOKEN="ghp_..."
export OPENAI_API_KEY="sk-..."
export AWS_ACCESS_KEY="..."
```

---

## Error Codes

### **Command Exit Codes**
- `0`: Success
- `1`: General error
- `2`: Invalid usage/arguments
- `3`: Missing dependencies
- `4`: Permission denied
- `5`: File/directory not found

### **Common Error Patterns**
- **"command not found"**: Tool not in PATH, check `path.zsh`
- **"permission denied"**: File ownership or executable permissions
- **"no such file"**: Missing configuration or broken symlink
- **"already exists"**: Symlink conflicts during bootstrap

---

## Troubleshooting Patterns

### **Diagnostic Commands**
```bash
# Check system status
dots status --verbose

# Verify symlink health  
dots status --symlinks

# Test configuration loading
ZSH=~/.dotfiles zsh -n ~/.zshrc

# Check for portability issues
./tests/unit/test_portability.sh

# Validate all configurations
./core/lib/validate-config.sh
```

### **Common Issues and Solutions**

#### **Topic Not Loading**
```bash
# Debug: Check loading order
zsh -x -c 'source ~/.zshrc 2>&1' | grep topic-name

# Fix: Verify file naming and permissions
ls -la ~/.dotfiles/topic-name/*.zsh
chmod +x ~/.dotfiles/topic-name/install.sh
```

#### **Command Not Found**
```bash
# Debug: Check PATH
echo $PATH | tr ':' '\n' | grep topic

# Fix: Ensure path.zsh sets PATH correctly
cat ~/.dotfiles/topic/path.zsh
```

#### **Symlinks Not Created**
```bash
# Debug: Check conflicts
ls -la ~/conflicting-file

# Fix: Remove conflicts and relink
rm ~/conflicting-file
dots relink --force
```

#### **Local Configs Not Applied**
```bash
# Debug: Check precedence
dots status

# Fix: Verify local directory
ls -la ~/.dotlocal
dots relink --clean
```

---

## Cross-Reference Index

### **By Topic**
- **Architecture**: [MICRODOTS.md](../MICRODOTS.md), [IMPLEMENTATION.md](IMPLEMENTATION.md)
- **Installation**: [README.md](../README.md), [IMPLEMENTATION.md](IMPLEMENTATION.md)
- **Configuration**: [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md), [MIGRATION_TO_DOTLOCAL.md](MIGRATION_TO_DOTLOCAL.md)
- **Development**: [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md), [IMPLEMENTATION.md](IMPLEMENTATION.md)
- **Testing**: [COMPLIANCE.md](COMPLIANCE.md), [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md)
- **AI Integration**: [CLAUDE.md](../CLAUDE.md), All documentation

### **By File Type**
- **Commands**: [IMPLEMENTATION.md](IMPLEMENTATION.md), This glossary
- **Variables**: This glossary, [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md)
- **Configuration**: [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md), [IMPLEMENTATION.md](IMPLEMENTATION.md)
- **UI Patterns**: [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md), This glossary

### **By User Role**
- **End Users**: [README.md](../README.md), [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md), This glossary
- **Developers**: [MICRODOTS.md](../MICRODOTS.md), [IMPLEMENTATION.md](IMPLEMENTATION.md), [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md)
- **System Administrators**: [IMPLEMENTATION.md](IMPLEMENTATION.md), [COMPLIANCE.md](COMPLIANCE.md)
- **AI Agents**: [CLAUDE.md](../CLAUDE.md), All documentation as specified

### **By Complexity Level**
- **Beginner**: [README.md](../README.md), [LOCAL_OVERRIDES.md](LOCAL_OVERRIDES.md) Quick Start
- **Intermediate**: [MICRODOTS.md](../MICRODOTS.md), [IMPLEMENTATION.md](IMPLEMENTATION.md) Core
- **Advanced**: Full [IMPLEMENTATION.md](IMPLEMENTATION.md), [UI_STYLE_GUIDE.md](UI_STYLE_GUIDE.md), [COMPLIANCE.md](COMPLIANCE.md)

---

*This glossary serves as the definitive reference for all Microdots terminology and concepts. It is actively maintained and updated with system changes.*

**Last Updated**: 2025-09-12  
**Version**: 1.0  
**Maintainer**: Microdots Documentation Team