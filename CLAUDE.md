# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 📚 MANDATORY READING REQUIREMENTS

### Before ANY work begins, you MUST read and internalize:

- Your configuration from @~/.claude/README.md
- Your protocol @~/.claude/PROTOCOL.md
- Strictly adhere to all documentation rules

## Project Overview

This is a **Microdots** system - a distributed, topic-centric dotfiles architecture for macOS that treats each configuration topic as an independent microservice. The system follows strict principles of self-containment, automatic discovery, and defensive programming.

## Common Development Commands

### System Management

```bash
# Initial setup (one-time)
dots bootstrap --install    # Complete setup: symlinks + installation

# Regular maintenance
dots status                 # Check system health
dots status -v              # Verbose status with all details
dots relink                 # Rebuild symlinks
dots maintenance            # Update packages and clean system

# Testing
tests/run_integration_tests.sh    # Run all 83 integration tests
tests/unit/test_portability.sh    # Check for hardcoded paths
tests/run_all_tests.sh           # Complete test suite
```

### MCP Server Management

```bash
# Setup MCP servers for Claude Code
mcp-setup-global           # Install MCP servers to ~/.claude/.claude.json
command mcp-status         # Check MCP server status (bypass function)
claude mcp list           # List configured servers

# Manual MCP operations
claude mcp add <name> npx --scope user -- -y <package>
claude mcp remove <name> --scope user
```

### Development Workflow

```bash
# Add new topic
mkdir ~/.dotfiles/newtopic
echo 'alias nt="echo works"' > ~/.dotfiles/newtopic/aliases.zsh
source ~/.zshrc  # Auto-discovers and loads

# Debug loading issues
ZSH=~/.dotfiles zsh -x -c 'source ~/.zshrc' 2>&1 | head -20

# Validate changes
tests/unit/test_portability.sh  # Check for portability issues
```

## Documentation

The `docs/` folder contains detailed architectural and implementation documentation:

- **`docs/ARCHITECTURE.md`** - Complete system architecture, topic structure, and installation flow
- **`docs/LOCAL_OVERRIDES.md`** - Comprehensive dotlocal system documentation with precedence rules
- **`docs/UI_STYLE_GUIDE.md`** - UI library usage and output formatting standards

Refer to these documents for in-depth understanding of specific subsystems.

## High-Level Architecture

### Core Design: Microservices for Dotfiles

The system treats each configuration topic as an **autonomous microservice** that:

- **Self-discovers** through filesystem conventions (no central registry)
- **Self-contains** all required files (zero coupling between topics)
- **Self-defends** against missing dependencies (graceful degradation)
- **Hot-deploys** without system restart (instant integration)

### Four-Stage Loading Orchestration

The shell initialization follows a precise loading order to ensure dependencies are met:

1. **PATH Setup** (`*/path.zsh`) - Ensures tools are available in PATH
2. **Configuration** (`*.zsh` except path/completion) - Loads aliases, functions, settings
3. **Completion Init** (`compinit`) - Initializes zsh completion system
4. **Completions** (`*/completion.zsh`) - Loads command-specific completions

This orchestration is implemented in `zsh/zshrc.symlink` and ensures that:

- Tools are in PATH before being configured
- Completions load after the completion system initializes
- Each stage can depend on the previous one

### Command Routing System

The `dots` command uses a sophisticated routing system:

```
bin/dots (router) → core/commands/<command> (implementation)
                 ↘ core/lib/common.sh (shared utilities)
                 ↘ core/lib/ui.sh (consistent UI)
```

Commands are discovered dynamically from `core/commands/`, allowing new commands to be added without modifying the router.

### Topic Independence Architecture

Topics are self-contained directories with automatic discovery through naming conventions:

**Standard Structure:**

```
topic/
├── install.sh         # Installation script (optional)
├── *.symlink         # Files to symlink to $HOME
├── path.zsh          # PATH setup (loaded first)
├── *.zsh            # Shell configs (loaded second)
└── completion.zsh    # Completions (loaded last)
```

**Modular Subtopics** (see claude/ for example):

- Parent topic contains subtopics with own install.sh scripts
- Each subtopic is completely independent
- Parent installer auto-discovers and runs subtopic installers

See `docs/ARCHITECTURE.md` for complete topic structure documentation.

### Private Layer System (Dotlocal)

The dotlocal system provides complete separation of public and private configurations:

- **Four-level precedence** for finding local directory:
  1. `dotfiles.conf` configuration (highest priority)
  2. `~/.dotfiles/local` symlink
  3. `~/.dotfiles/local` directory
  4. `~/.dotlocal` directory (default)
- **Local always wins** - Private configs completely replace public ones
- **Cloud sync compatible** - Can link to iCloud/Dropbox directories
- **Same structure** as public topics for consistency

See `docs/LOCAL_OVERRIDES.md` for complete dotlocal documentation including migration guides and testing procedures.

### MCP Integration Architecture

The MCP (Model Context Protocol) subsystem has two configuration paths:

1. **servers.json** - Source of truth in `.local/claude/mcp/servers.json`
2. **~/.claude/.claude.json** - Claude Code's runtime configuration

The `mcp-setup-global` script properly configures servers using:

```bash
claude mcp add <server> <command> --scope user -- <args>
```

Note: Command and arguments must be separated properly or servers will fail with posix_spawn errors.

### Configuration Validation System

`core/lib/validate-config.sh` implements safety checks preventing:

- Multiple LOCAL_PATH definitions
- Executable commands in config files
- Invalid variable syntax
- Circular symlinks

This runs automatically before operations like `dots relink` to prevent system damage.

### Test Framework Architecture

The comprehensive test suite validates system integrity:

**Test Categories:**

- `tests/unit/` - Portability and hardcoded path detection
- `tests/integration/` - 83 tests for topic independence and system behavior
- `tests/edge_cases/` - Security and edge case handling

**Key Test Files:**

- `test_framework.sh` - Shared testing utilities with colored output
- `run_integration_tests.sh` - Main test runner
- `test_portability.sh` - Detects hardcoded paths/usernames
- `test_complete_portability.sh` - Full system validation

Tests ensure topics remain independent, paths stay portable, and defensive programming works correctly.

## Critical Implementation Details

### Symlink Management

- Files ending in `.symlink` are linked to `$HOME` without the extension
- Directories ending in `.symlink` become directory symlinks
- Conflicts are detected and reported during `dots bootstrap`

### Homebrew Path Handling

The system detects and handles both Homebrew locations:

- `/opt/homebrew` (Apple Silicon)
- `/usr/local` (Intel)

### Environment Variables

Key variables used throughout:

- `$ZSH` - Points to `~/.dotfiles`
- `$PROJECTS` - User's code directory (default: `~/Code`)
- `$LOCAL_PATH` - Private config directory (configured in `dotfiles.conf`)

### Security Considerations

- `compinit -u` flag used to suppress Homebrew directory warnings
- Configuration files validated before sourcing
- Sensitive data kept in `.local/` (not committed)

## Important Patterns to Maintain

1. **Always use defensive programming** - Check before configuring
2. **Respect topic boundaries** - No cross-topic dependencies
3. **Follow naming conventions** - Enables automatic discovery
4. **Test portability** - Run tests before committing
5. **Use UI library** - Source `core/lib/ui.sh` for consistent output
6. **Preserve loading order** - path → config → compinit → completions

## Known Issues and Workarounds

- **mcp-status function conflict**: Use `command mcp-status` to bypass shell function
- **MCP server failures**: Ensure command/args properly separated in `claude mcp add`
- **Homebrew warnings**: Normal due to ownership differences, suppressed with `compinit -u`
