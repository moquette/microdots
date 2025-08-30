# Set Homebrew environment (works on both Intel and Apple Silicon)
if command -v brew &>/dev/null; then
  # Disable Homebrew analytics and environment hints
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_ENV_HINTS=1
  
  # === Homebrew Environment Config ===
  eval "$(brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
  # Apple Silicon fallback
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_ENV_HINTS=1
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  # Intel Mac fallback
  export HOMEBREW_NO_ANALYTICS=1
  export HOMEBREW_NO_ENV_HINTS=1
  eval "$(/usr/local/bin/brew shellenv)"
fi