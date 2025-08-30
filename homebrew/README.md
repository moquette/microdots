# Homebrew Microdot - Package Management Foundation

This microdot provides **unopinionated** Homebrew integration with intelligent architecture detection.

## Philosophy

The public Homebrew microdot only provides:
1. **Homebrew installation** - Installs Homebrew itself if missing
2. **Path detection** - Automatically handles M1 vs Intel Macs
3. **Environment setup** - Proper shell integration
4. **Bundle support** - Infrastructure for Brewfiles (but no packages forced)

It does NOT install any packages - that's your choice!

## What This Provides

### Automatic Architecture Detection

The microdot automatically detects and configures the correct Homebrew location:
- **Apple Silicon (M1/M2/M3)**: `/opt/homebrew`
- **Intel Macs**: `/usr/local`
- **Linux**: `/home/linuxbrew/.linuxbrew`

This means your dotfiles work seamlessly across different machines!

### Files

- `path.zsh` - Sets up Homebrew in PATH (architecture-aware)
- `env.zsh` - Environment variables and completion setup
- `install.sh` - Installs Homebrew itself (if missing)
- `install-brewfile.sh` - Processes Brewfiles from your local config
- `Brewfile.example` - Comprehensive template with common packages

## Setting Up Your Packages

### Step 1: Create Your Local Brewfile

```bash
mkdir -p ~/.dotlocal/homebrew
cp ~/.dotfiles/homebrew/Brewfile.example ~/.dotlocal/homebrew/Brewfile
# Edit to uncomment/add your desired packages
```

### Step 2: Install Your Packages

```bash
# Install everything in your Brewfile
brew bundle --file=~/.dotlocal/homebrew/Brewfile

# Or use dots install to run all installers
dots install
```

### Step 3: Keep It Updated

```bash
# Update all packages
brew update && brew upgrade

# Or use dots maintenance
dots maintenance
```

## Brewfile Organization

You can organize your packages however you like:

### Single File Approach
```
~/.dotlocal/homebrew/
└── Brewfile          # Everything in one file
```

### Multi-File Approach
```
~/.dotlocal/homebrew/
├── Brewfile          # Core tools
├── Brewfile.dev     # Development tools
├── Brewfile.apps    # GUI applications
└── install.sh       # Custom installation logic
```

To use multiple Brewfiles:
```bash
brew bundle --file=~/.dotlocal/homebrew/Brewfile.dev
brew bundle --file=~/.dotlocal/homebrew/Brewfile.apps
```

## Example Packages

The `Brewfile.example` includes categories for:
- Core Unix tools (coreutils, findutils, etc.)
- Modern CLI tools (ripgrep, fd, bat, fzf)
- Development languages (node, python, go, rust)
- Package managers (yarn, poetry, cargo)
- Development tools (gh, neovim, tmux)
- Container tools (docker, kubectl, helm)
- Database tools (postgresql, redis)
- GUI applications (vscode, iterm2, docker desktop)

## Why This Approach?

1. **No forced dependencies** - You choose what to install
2. **Architecture portable** - Works on M1, Intel, and Linux
3. **Team-friendly** - Share the structure, not the opinions
4. **Beginner-friendly** - Example file guides new users
5. **Power-user ready** - Full flexibility for complex setups

## Tips

- Use `brew leaves` to see what you've explicitly installed
- Use `brew bundle dump` to generate a Brewfile from current state
- Consider using `mas` (Mac App Store CLI) for App Store apps
- Group related tools in comments for organization
- Version pin critical tools if needed: `brew 'node@16'`

## Troubleshooting

If Homebrew commands aren't found:
1. Restart your terminal
2. Run `source ~/.zshrc`
3. Check `echo $PATH` includes Homebrew's bin directory
4. Verify installation: `/opt/homebrew/bin/brew --version` (M1) or `/usr/local/bin/brew --version` (Intel)