# Setup Homebrew environment based on architecture
if [[ -f "/opt/homebrew/bin/brew" ]]; then
  # Apple Silicon
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
  # Intel Mac
  eval "$(/usr/local/bin/brew shellenv)"
fi