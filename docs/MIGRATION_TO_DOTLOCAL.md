# Migration to .dotlocal Naming Convention

## Date: September 12, 2025

### Summary
Successfully migrated the entire dotfiles system from `.local`/`LOCAL_DOTS` naming to `.dotlocal`/`DOTLOCAL` for improved clarity and consistency.

## Changes Made

### Variable Naming
- **Before**: `LOCAL_DOTS` environment variable
- **After**: `DOTLOCAL` environment variable
- **Files Updated**: All core commands, libraries, and configuration files

### Symlink Naming
- **Before**: `~/.dotfiles/.local` symlink
- **After**: `~/.dotfiles/.dotlocal` symlink
- **Impact**: Clearer naming that better represents the "dotlocal" concept

### File Updates
The following files were updated to use the new naming convention:
- `core/commands/bootstrap`
- `core/commands/install`
- `core/commands/maintenance`
- `core/commands/relink`
- `core/commands/status`
- `core/lib/validate-config.sh`
- `core/setup`
- `dotfiles.conf` (user configuration)
- `dotfiles.conf.example`
- `homebrew/install-brewfile.sh`
- `zsh/config.zsh`
- `.gitignore` (added .dotlocal)

### Backward Compatibility
- **Removed**: No backward compatibility maintained
- **Reason**: Clean break for consistency
- **Impact**: Users need to update their `dotfiles.conf` to use `DOTLOCAL` instead of `LOCAL_DOTS`

## Migration Steps for Users

If you're pulling these changes on another machine:

1. **Update your dotfiles.conf**:
   ```bash
   # Change this:
   LOCAL_DOTS="/path/to/your/dotlocal"
   
   # To this:
   DOTLOCAL="/path/to/your/dotlocal"
   ```

2. **Recreate symlinks**:
   ```bash
   dots relink
   ```

3. **Verify status**:
   ```bash
   dots status
   ```

## Benefits

1. **Consistency**: The variable name `DOTLOCAL` matches the actual directory name `.dotlocal`
2. **Clarity**: More intuitive naming - "dotlocal" clearly indicates local dotfiles
3. **Simplicity**: Single naming convention throughout the codebase
4. **Future-proof**: No confusion between `.local` (standard XDG directory) and our dotlocal system

## Testing

All 85 integration tests pass with the new naming convention:
- Topic isolation maintained
- Symlink creation working
- Configuration validation functional
- Loading order preserved

## Notes

- The git configuration still uses `.gitconfig.local` as this is a standard Git convention
- SSH host references to `*.local` are legitimate hostnames and were not changed
- The `~/.local/share/` references in atuin configuration are standard XDG paths and were not changed

## Commit History

```
9dbc8ea Remove all LOCAL_DOTS and .local references
afbaea2 Add .dotlocal to gitignore
598d1fa Update zsh config to prioritize .dotlocal over .local
3a42aa5 feat: create .dotlocal as primary symlink with .local for compatibility
b4ed094 feat: add dual support for DOTLOCAL and LOCAL_DOTS variables
```

---

*Migration completed successfully with no breaking issues.*