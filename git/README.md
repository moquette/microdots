# Git Microdot - Minimal Foundation

This microdot provides the **absolute minimum** Git configuration while preserving the first-time setup experience.

## Philosophy

The public git configuration contains only:
1. **Include mechanism** - Points to user's local config
2. **Essential defaults** - Prevents Git warnings
3. **Bootstrap integration** - First-time user setup

Everything else (colors, aliases, preferences) belongs in your local configuration.

## First-Time Setup

When you run `dots bootstrap` for the first time, it will:
1. Detect that you don't have a `~/.gitconfig.local`
2. Prompt for your name and email
3. Create the file with your information
4. Automatically detect the right credential helper for your OS

This provides a smooth onboarding experience while keeping the public config minimal.

## Files

- `gitconfig.symlink` → `~/.gitconfig` - Minimal public configuration
- `gitconfig.local.symlink.example` - Template with ALL options documented
- `gitignore.symlink` → `~/.gitignore` - Global ignore patterns
- `completion.zsh` - Git completion support

## Customization

Your `~/.gitconfig.local` (created by bootstrap or manually) should contain:
- **Required**: Your name, email, and credential helper
- **Optional**: Any personal preferences (colors, aliases, tools, etc.)

The example file shows all common options with documentation.

## What This Does NOT Include

Unlike many dotfiles repos, this does NOT force:
- Color schemes (though Git usually defaults to color anyway)
- Aliases (create your own!)
- Pull strategy (rebase vs merge is personal/team choice)
- Autocorrect settings
- Diff/merge tools
- Whitespace handling

## Why This Approach?

1. **New users** get a working Git setup with zero opinions forced on them
2. **Experienced users** can bring their existing preferences
3. **Teams** can share the structure without forcing workflows
4. **Bootstrap** still provides the friendly first-time experience

## Examples

### Minimal User (just the basics)
```ini
[user]
    name = Jane Developer
    email = jane@example.com
[credential]
    helper = osxkeychain
```

### Power User (fully customized)
```ini
[user]
    name = Jane Developer
    email = jane@example.com
[credential]
    helper = osxkeychain
[color]
    ui = true
[alias]
    co = checkout
    br = branch
    unstage = reset HEAD --
[pull]
    rebase = true
[commit]
    gpgsign = true
```

The choice is yours!