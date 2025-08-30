# Dotfiles Architecture

## Overview

This dotfiles repository uses a **modular, topic-centric architecture** with dynamic discovery. Each aspect of system configuration is organized into self-contained topics that can be added, removed, or modified independently.

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

## Topics

Topics are self-contained directories that configure specific aspects of the system:

### Topic Structure

```
topic-name/
├── install.sh            # Optional: Installation script
├── *.symlink            # Files to be symlinked to $HOME
├── *.zsh                # Shell configuration files
├── path.zsh             # PATH modifications (loaded first)
├── completion.zsh       # Completions (loaded last)
└── README.md            # Topic documentation
```

### Dynamic Discovery

The system automatically discovers topics through:

1. **Installation**: Any directory with an `install.sh` script
2. **Symlinks**: Any `*.symlink` files are linked to `$HOME`
3. **Shell Config**: Any `*.zsh` files are sourced by the shell

### Current Topics

- **`claude/`**: AI assistant configuration with modular subtopics
- **`git/`**: Git configuration and aliases
- **`homebrew/`**: Package management
- **`macos/`**: macOS system preferences
- **`node/`**: Node.js and npm configuration
- **`ruby/`**: Ruby environment setup
- **`system/`**: System utilities and aliases
- **`vim/`**: Vim configuration
- **`zsh/`**: Shell configuration

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

### Simple Topic

Create a new directory with configuration files:

```bash
my-topic/
├── config.symlink       # Will be linked to ~/.config
└── aliases.zsh          # Will be sourced by shell
```

### Topic with Installation

Add an `install.sh` for complex setup:

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

## Best Practices

1. **Keep Topics Self-Contained**: Each topic should work independently
2. **Use Common Functions**: Leverage `common.sh` for consistency
3. **Provide Feedback**: Use info/success/warning/error functions
4. **Handle Errors Gracefully**: Check for dependencies and prerequisites
5. **Document Topics**: Include README.md in each topic
6. **Test Modularity**: Ensure topics can be added/removed cleanly

## Environment Variables

- `$DOTFILES_ROOT`: Path to dotfiles directory (usually `~/.dotfiles`)
- `$ZSH`: Same as `$DOTFILES_ROOT` (for compatibility)
- `$PROJECTS`: Default project directory (usually `~/Code`)

## File Loading Order (zsh)

1. All `*/path.zsh` files (PATH setup)
2. All other `*.zsh` files except completions
3. `compinit` (initialize autocomplete)
4. All `*/completion.zsh` files

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