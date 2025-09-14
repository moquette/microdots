# Microdots

**Microservices architecture for your dotfiles**

---

## The Revolution

What if your dotfiles worked like modern distributed systems? What if each piece of your development environment was an independent service that could be deployed, scaled, and removed without breaking anything else?

**Traditional dotfiles are monoliths.** One massive configuration that's impossible to maintain, share, or customize. Change one thing, break everything else. Fork someone's dotfiles, inherit all their opinions.

**Microdots are different.**

This isn't just another dotfiles repository. This is a **paradigm shift** — applying distributed systems architecture to configuration management. Each "microdot" is an autonomous service that discovers itself, provisions itself, and can be removed atomically.

Welcome to the future of dotfiles.

---

## ⚡ Lightning Quick Start

# One command install the microdots system -- follow the prompts

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/moquette/microdots/main/core/setup)"
```

**That's it.** Your development environment is now a distributed system.

---

## 🏗️ The Architecture

### Zero-Coupling Design

Every microdot (topic) is completely **self-contained**:

```
git/                  # Git microdot
├── aliases.zsh       # Git shortcuts
├── gitconfig.symlink # Core configuration
├── completion.zsh    # Tab completions
└── install.sh        # Dependency setup

docker/               # Docker microdot
├── aliases.zsh       # Docker shortcuts
├── path.zsh          # PATH modifications
└── install.sh        # Docker setup
```

### Automatic Service Discovery

No manifests. No registries. No hardcoded lists. The filesystem **IS** the configuration:

```bash
# The system discovers microdots automatically:
for file in $ZSH/**/path.zsh; do source $file; done      # PATH setup
for file in $ZSH/**/*.zsh; do source $file; done         # Load configs
for file in $ZSH/**/completion.zsh; do source $file; done # Completions
```

Drop a directory with the right naming convention → **it just works**.  
Remove a directory → **nothing breaks**.

### Bulletproof Self-Containment

Each microdot follows the **service autonomy principle**:

- **Independent**: Add or remove without affecting other microdots
- **Complete**: Contains everything needed for that functionality
- **Discoverable**: Uses standard naming conventions for auto-loading
- **Defensive**: Gracefully handles missing dependencies

```bash
# Defensive programming example
if command -v rbenv >/dev/null 2>&1; then
  eval "$(rbenv init -)"
fi
```

---

## 📁 Microdot Anatomy

Every microdot is a **bounded context** that manages its complete lifecycle:

### Runtime Integration

- `*.zsh` → Shell aliases, functions, configurations
- `path.zsh` → Environment variables and PATH setup (loaded first)
- `completion.zsh` → Tab completions (loaded after compinit)

### System Integration

- `*.symlink` → Configuration files linked to `$HOME`
- `install.sh` → Dependency installation and setup

### Loading Orchestration

```bash
# 1. PATH setup (ensures tools available)
# 2. Configuration loading (aliases, functions)
# 3. Completion initialization
# 4. Completion loading
```

Perfect **separation of concerns** with **predictable execution order**.

---

## 🎯 Core Microdots

The system includes foundational microdots that demonstrate the patterns:

### Essential Infrastructure

- **`core/`** - Command routing and shared utilities
- **`zsh/`** - Shell configuration and functions
- **`homebrew/`** - Package management foundation

### Development Tools

- **`git/`** - Version control configuration
- **`system/`** - macOS system preferences

### Example Patterns (Commented Templates)

- **`claude/`** - AI configuration management example
- **`mcp/`** - Model Context Protocol setup example

Each example microdot shows **best practices** while remaining **completely optional** — delete what you don't need without breaking anything.

---

## 🚀 Command Interface

Microdots provides a clean command interface:

```bash
# System lifecycle
dots bootstrap              # Initial setup and symlinks
dots install               # Run all microdot installations
dots bootstrap --install   # One-command complete setup

# System management
dots status                       # Configuration status
dots relink                      # Rebuild all symlinks
dots maintenance                 # System maintenance

# Infrastructure management
dots repair-infrastructure       # Validate and repair infrastructure symlinks
dots repair-infrastructure -q    # Quiet repair mode
dots repair-infrastructure -p ~/.dotlocal  # Specify dotlocal path

# Advanced operations
dots status -v                   # Verbose system information
dots relink --dry-run            # Preview changes
dots maintenance --quick         # Skip package updates
```

---

## 🔒 Private Configuration Layer

Keep sensitive data separate with the **dotlocal system** — now with **automatic discovery**!

### Zero-Configuration Setup

The system uses a **5-level auto-discovery hierarchy** to automatically find your dotlocal configuration:

#### Discovery Precedence (Highest to Lowest Priority)

1. **Explicit Configuration** - `dotfiles.conf` with `DOTLOCAL` variable
2. **Existing Symlink** - `~/.dotfiles/.dotlocal` symlink to your dotlocal
3. **Existing Directory** - `~/.dotfiles/.dotlocal` directory
4. **Standard Location** - `~/.dotlocal` (default hidden directory)
5. **Cloud Storage Auto-Discovery** - Automatically scans:
   - iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/Dotlocal`)
   - Dropbox (`~/Dropbox/Dotlocal`)
   - Google Drive (`~/Google Drive/Dotlocal`)
   - OneDrive (`~/OneDrive/Dotlocal`)
   - Network volumes (`/Volumes/*/Dotlocal`)

**✅ Production Ready**: The 5-level auto-discovery system is thoroughly tested and production-ready. Fresh installs work flawlessly with zero configuration required.

#### Infrastructure Symlinks

The system automatically creates **6 infrastructure symlinks** in your dotlocal directory:

```bash
~/.dotlocal/
├── core → ~/.dotfiles/core                    # UI library and utilities
├── docs → ~/.dotfiles/docs                    # Documentation directory
├── MICRODOTS.md → ~/.dotfiles/MICRODOTS.md    # Architecture guide
├── CLAUDE.md → ~/.dotfiles/CLAUDE.md          # AI agent configuration
├── TASKS.md → ~/.dotfiles/TASKS.md            # Project tasks
└── COMPLIANCE.md → ~/.dotfiles/docs/architecture/COMPLIANCE.md  # Compliance documentation
```

These symlinks provide essential infrastructure access while maintaining the zero-coupling principle. They enable proper tooling, documentation access, and development support without creating functional dependencies between microdots.

### Quick Start

```bash
# Option 1: Use default location (auto-created)
mkdir -p ~/.dotlocal

# Option 2: Use cloud storage (auto-discovered)
mkdir -p ~/Library/Mobile\ Documents/com~apple~CloudDocs/Dotlocal

# Option 3: Explicit configuration
echo 'DOTLOCAL="/path/to/your/dotlocal"' > ~/.dotfiles/dotfiles.conf
```

### Structure

```bash
~/.dotlocal/
├── ssh.symlink/          # Private SSH keys
├── git/
│   └── gitconfig.symlink # Personal git config
└── shell/
    └── localrc.symlink   # Secret environment variables
```

**Local configurations always override public ones** — perfect for API keys, personal preferences, and machine-specific settings.

---

## 🧪 Battle-Tested Reliability

### Comprehensive Testing

- **83 integration tests** covering topic independence
- **Unit tests** for portability and hardcoded path detection
- **Custom test framework** with color-coded results
- **Cross-system validation** across different macOS setups

```bash
# Validate your setup
tests/run_integration_tests.sh
tests/unit/test_portability.sh
```

### Defensive Programming

Every script includes **graceful failure handling**:

- Checks for tool existence before configuring
- Platform-specific command guards
- Multiple installation path support
- Comprehensive error handling

---

## ✨ Creating Your Own Microdots

Building a new microdot is **dead simple**:

```bash
# 1. Create the microdot
mkdir ~/.dotfiles/newtopic

# 2. Add functionality files
echo 'alias nt="echo New topic works!"' > ~/.dotfiles/newtopic/aliases.zsh
echo 'export PATH="$HOME/.newtopic/bin:$PATH"' > ~/.dotfiles/newtopic/path.zsh

# 3. Add installation logic
cat > ~/.dotfiles/newtopic/install.sh << 'EOF'
#!/usr/bin/env bash
echo "Installing new topic..."
# Your installation logic here
EOF
chmod +x ~/.dotfiles/newtopic/install.sh

# 4. Test immediately
source ~/.zshrc && nt
```

The microdot **automatically integrates** — no registration, no manifests, no central coordination required.

---

## 🎨 Customization Philosophy

### Unopinionated Foundation

The public repository provides **patterns and infrastructure**, not opinions:

- Core loading mechanisms
- Essential development tools
- Example microdots as templates
- Comprehensive testing framework

### Personal Layer

Your customizations live in **dotlocal**:

- Private configurations
- Personal tool preferences
- Machine-specific settings
- Workflow-specific aliases

This separation ensures you can **pull updates** from the public repository without conflicts while maintaining your personal setup.

---

## 🔧 Advanced Operations

### System Maintenance

```bash
# Comprehensive maintenance
dots maintenance                 # Full system update

# Targeted maintenance
dots maintenance --clean         # Cleanup only
dots maintenance --dry-run       # Preview changes
```

### Symlink Management

```bash
# Rebuild configuration links
dots relink                      # Standard rebuild
dots relink --force              # Overwrite existing
dots relink --clean              # Remove broken links first
```

### Status and Debugging

```bash
# System health check
dots status                      # Basic status
dots status -v                   # Verbose information
dots status -s                   # Show all symlinks

# Debug installation issues
bash -x ~/.dotfiles/core/commands/bootstrap
tests/unit/test_portability.sh
```

---

## 🛠️ Troubleshooting

### Quick Diagnostics

```bash
# Verify core system
echo $ZSH                        # Should show ~/.dotfiles
which brew                       # Homebrew installed
git config --get user.name      # Git configured

# Debug loading
ZSH=~/.dotfiles zsh -x -c 'source ~/.zshrc' 2>&1 | head -20

# Check auto-discovery system
dots status --verbose            # See dotlocal discovery results
```

### Common Issues

#### Configuration Issues
- **Missing configurations**: Run `dots bootstrap` to recreate symlinks
- **Commands not found**: Verify PATH with `echo $PATH | grep dotfiles`
- **Dotlocal not found**: System auto-creates `~/.dotlocal` on bootstrap

#### Infrastructure Issues
- **Infrastructure symlinks missing**: Run `dots repair-infrastructure`
- **Broken symlinks**: Use `dots status -v` to diagnose, then repair
- **Discovery failing**: Check `dots status --verbose` for discovery details

#### Platform Issues
- **Homebrew issues**: Check installation paths for Apple Silicon vs Intel
- **Cloud storage sync**: Verify cloud directories are accessible and synced

#### System Recovery
- **Complete corruption**: Run `dots bootstrap --install` for full recovery
- **Partial issues**: Use `dots repair-infrastructure` for targeted repair
- **Debug discovery**: Enable verbose mode with `dots status --verbose`

#### Fixed Issues
- **✅ Bootstrap auto-recovery**: System now auto-recovers from missing dotlocal configurations
- **✅ Command substitution**: Fixed debug output contamination that caused symlink corruption
- **✅ Zero-configuration**: Fresh installs now work without any manual setup

---

## 🤝 Contributing

When building new microdots:

1. **Follow self-containment** - Each microdot works independently
2. **Use defensive programming** - Check dependencies before configuring
3. **Follow naming conventions** - Enable automatic discovery
4. **Use symlink.sh library** - Never call `ln -s` directly, use appropriate specialized functions
5. **Add tests** - Verify portability and independence
6. **Document patterns** - Help others understand the approach

### Symlink Architecture

The system uses a **Three-Tier Symlink Architecture** for consistency:

- **NEVER use direct `ln -s`** - Use `core/lib/symlink.sh` library functions
- **Infrastructure**: `create_infrastructure_symlink()` for core/docs access
- **Bootstrap**: `create_bootstrap_symlink()` for early setup
- **Applications**: `create_application_symlink()` for app configs
- **Commands**: `create_command_symlink()` for CLI tools

Only `_create_symlink_raw()` is allowed to call `ln -s` - this ensures consistent error handling and command substitution safety.

```bash
# Test your contributions
tests/run_integration_tests.sh
tests/unit/test_portability.sh
```

---

## 🧠 The Philosophy

This system embodies **distributed systems principles**:

- **Service Discovery**: Automatic detection through filesystem conventions
- **Autonomous Services**: Each microdot manages its complete lifecycle
- **Zero Coupling**: Remove any microdot without cascading failures
- **Hot Deployment**: Add functionality without system restarts
- **Defensive Programming**: Graceful handling of missing dependencies

**Your dotfiles are now a distributed system.** Each microdot is an independent service that can be developed, deployed, and maintained separately while composing into a cohesive whole.

The result? A configuration system that's **bulletproof**, **maintainable**, and **infinitely customizable**.

---

_Transform your development environment from a fragile monolith into an elegant distributed system. Welcome to Microdots._
