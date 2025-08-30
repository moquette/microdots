# ZSH Microdot - Minimal Foundation

This microdot provides the **absolute minimum** required for the Microdots system to function. It is intentionally unopinionated.

## What This Provides

1. **Loading Orchestration** - The four-stage loading system that ensures proper dependency order
2. **Function Autoloading** - Support for custom ZSH functions
3. **Local Override Support** - Automatic discovery of local configurations
4. **Basic History** - Minimal history setup (1000 lines default)

## What This Does NOT Provide

- Color schemes or preferences
- Key bindings
- Aliases
- Shell options (beyond the essential two for functions)
- Prompt configuration
- Completion options

## How to Customize

All customization should be done in your **local** zsh microdot:

```bash
# Create your local zsh microdot
mkdir -p ~/.dotlocal/zsh

# Add your preferences
cat > ~/.dotlocal/zsh/preferences.zsh << 'EOF'
# Your color scheme
export LSCOLORS="..."

# Your history size
HISTSIZE=50000
SAVEHIST=50000

# Your shell options
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
# ... etc

# Your key bindings
bindkey '^R' history-incremental-search-backward
# ... etc
EOF
```

## Files in This Microdot

- `zshrc.symlink` - Minimal loading orchestration (links to ~/.zshrc)
- `config.zsh` - Function path setup and essential options
- `fpath.zsh` - Adds functions directory to fpath
- `completion.zsh` - Basic completion initialization

## Philosophy

The public ZSH microdot is a **pattern**, not a preference. It provides the mechanism for loading and organizing your configuration, but makes no assumptions about what that configuration should be.

This allows:
- New users to start with a clean slate
- Experienced users to bring their own preferences
- Teams to share the structure without forcing preferences
- Maximum flexibility and portability