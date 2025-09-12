# Minimal ZSH configuration - unopinionated foundation
# All personal preferences should go in your local zsh microdot

# Add functions to fpath - local functions take precedence
# Check for local functions directory using same resolution as dotlocal system
LOCAL_FUNCTIONS=""
if [[ -f "$ZSH/dotfiles.conf" ]]; then
  source "$ZSH/dotfiles.conf"
  if [[ -n "$LOCAL_PATH" ]] && [[ -d "$(eval echo "$LOCAL_PATH")/functions" ]]; then
    LOCAL_FUNCTIONS="$(eval echo "$LOCAL_PATH")/functions"
  fi
fi

# Fallback checks if not found via config
if [[ -z "$LOCAL_FUNCTIONS" ]]; then
  # Check .dotlocal first (new standard)
  if [[ -L "$ZSH/.dotlocal" ]] && [[ -d "$(readlink "$ZSH/.dotlocal")/functions" ]]; then
    LOCAL_FUNCTIONS="$(readlink "$ZSH/.dotlocal")/functions"
  elif [[ -d "$ZSH/.dotlocal/functions" ]]; then
    LOCAL_FUNCTIONS="$ZSH/.dotlocal/functions"
  # Fallback to .local for backward compatibility
  elif [[ -L "$ZSH/.local" ]] && [[ -d "$(readlink "$ZSH/.local")/functions" ]]; then
    LOCAL_FUNCTIONS="$(readlink "$ZSH/.local")/functions"
  elif [[ -d "$ZSH/.local/functions" ]]; then
    LOCAL_FUNCTIONS="$ZSH/.local/functions"
  elif [[ -d "$HOME/.dotlocal/functions" ]]; then
    LOCAL_FUNCTIONS="$HOME/.dotlocal/functions"
  fi
fi

# Add to fpath with local taking precedence
if [[ -n "$LOCAL_FUNCTIONS" ]]; then
  fpath=($LOCAL_FUNCTIONS $ZSH/functions $fpath)
  # Autoload functions from both directories
  autoload -U $LOCAL_FUNCTIONS/*(:t) 2>/dev/null
  autoload -U $ZSH/functions/*(:t)
else
  fpath=($ZSH/functions $fpath)
  autoload -U $ZSH/functions/*(:t)
fi

# Minimal history setup - just ensure history works
# Users can override these in their local config
HISTFILE=${HISTFILE:-~/.zsh_history}
HISTSIZE=${HISTSIZE:-1000}
SAVEHIST=${SAVEHIST:-1000}

# Essential options for function loading to work properly
setopt LOCAL_OPTIONS  # Allow functions to have local options
setopt LOCAL_TRAPS    # Allow functions to have local traps

# Note: All other options (completion, history behavior, key bindings, etc.)
# should be configured in your local zsh microdot for full customization
