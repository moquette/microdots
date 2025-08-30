# Bin Directory - Dots Command

This directory contains the `dots` command that manages the Microdots system.

## Purpose

This is NOT a general-purpose bin directory for user scripts. It contains ONLY:
- `dots` - The main command router
- `path.zsh` - Minimal PATH setup to make `dots` available

## Philosophy

The bin directory is part of the Microdots infrastructure, not a place for user customization.

For your own scripts and commands, create:
- `~/.dotlocal/bin/` - Your personal scripts
- `~/.local/bin/` - XDG standard location for user binaries

## The Dots Command

The `dots` command is the central interface to the Microdots system:

```bash
dots bootstrap    # Initial setup
dots install      # Run all installers
dots status       # Check system status
dots relink       # Rebuild symlinks
dots maintenance  # System maintenance
dots help         # Get help
```

## Why Separate?

Keeping this directory minimal ensures:
1. The core system remains unopinionated
2. Users can't accidentally break the dots command
3. Clear separation between infrastructure and user space

## Adding Your Own Commands

Create your local bin directory:
```bash
mkdir -p ~/.dotlocal/bin
```

Add to your PATH in `~/.dotlocal/system/path.zsh`:
```bash
export PATH="$HOME/.dotlocal/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
```

This keeps your scripts separate from the Microdots infrastructure.