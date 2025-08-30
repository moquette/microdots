#!/usr/bin/env zsh
# Minimal PATH setup - ONLY to ensure the dots command is available
# This is the only "opinionated" thing we enforce: making our own tools available

# Add the dotfiles bin directory to PATH so 'dots' command works
export PATH="$ZSH/bin:$PATH"

# That's it! No other PATH modifications.
# Users should set up their own PATH preferences in their local microdots.