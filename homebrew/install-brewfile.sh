#!/bin/sh
#
# Legacy Brewfile installer - for backward compatibility
# The modern approach is to use local homebrew microdot with its own install.sh
#

# Get the dotfiles root directory
DOTFILES_ROOT="${DOTFILES_ROOT:-$HOME/.dotfiles}"

# Load DOTLOCAL or LOCAL_DOTS from dotfiles.conf if it exists
LOCAL_DIR=""
if [[ -f "$DOTFILES_ROOT/dotfiles.conf" ]]; then
    # Source only variable assignments, not commands
    eval "$(grep '^[A-Z_]*=' "$DOTFILES_ROOT/dotfiles.conf" 2>/dev/null || true)"
    
    # Support both variable names (DOTLOCAL takes precedence)
    if [[ -n "$DOTLOCAL" ]]; then
        LOCAL_DIR="$DOTLOCAL"
    elif [[ -n "$LOCAL_DOTS" ]]; then
        LOCAL_DIR="$LOCAL_DOTS"
    fi
fi

echo "› Homebrew Brewfile installer (legacy)"
echo ""
echo "Note: The recommended approach is to create a local homebrew microdot:"
echo "  ~/.dotlocal/homebrew/Brewfile    - Your packages"
echo "  ~/.dotlocal/homebrew/install.sh  - Installation script"
echo ""
echo "This will be automatically executed during 'dots install'"
echo ""

# Check if local homebrew microdot exists
if [ -n "$LOCAL_DIR" ] && [ -d "$LOCAL_DIR/homebrew" ]; then
  if [ -f "$LOCAL_DIR/homebrew/install.sh" ]; then
    echo "✓ Local homebrew microdot found - will be handled by 'dots install'"
    echo "  Run: dots install"
    exit 0
  elif [ -f "$LOCAL_DIR/homebrew/Brewfile" ]; then
    echo "› Found Brewfile but no install.sh"
    echo "› Installing from: $LOCAL_DIR/homebrew/Brewfile"
    if brew bundle --file="$LOCAL_DIR/homebrew/Brewfile"; then
      echo "✓ Local Brewfile installed"
    else
      echo "✗ Failed to install local Brewfile"
      exit 1
    fi
  fi
else
  # Check for legacy location
  if [ -n "$LOCAL_DIR" ] && [ -f "$LOCAL_DIR/Brewfile" ]; then
    echo "› Installing from legacy location: $LOCAL_DIR/Brewfile"
    echo "  Consider moving to: $LOCAL_DIR/homebrew/Brewfile"
    if brew bundle --file="$LOCAL_DIR/Brewfile"; then
      echo "✓ Local Brewfile installed (legacy location)"
    else
      echo "✗ Failed to install local Brewfile"
      exit 1
    fi
  else
    echo "› No local Brewfile found"
    echo ""
    echo "To set up your packages:"
    echo "  1. Create: $LOCAL_DIR/homebrew/Brewfile"
    echo "  2. Copy example: cp $DOTFILES_ROOT/homebrew/Brewfile.example $LOCAL_DIR/homebrew/Brewfile"
    echo "  3. Edit to add your packages"
    echo "  4. Run: dots install"
  fi
fi

echo ""
echo "✓ Homebrew bundle check complete"