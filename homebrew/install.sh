#!/bin/sh
#
# Homebrew
#
# This installs some of the common dependencies needed (or at least desired)
# using Homebrew.

# Check for Homebrew in standard locations
check_brew() {
  if test -f "/opt/homebrew/bin/brew"; then
    /opt/homebrew/bin/brew --version >/dev/null 2>&1
    return $?
  elif test -f "/usr/local/bin/brew"; then
    /usr/local/bin/brew --version >/dev/null 2>&1
    return $?
  elif command -v brew >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Install Homebrew if not found
if ! check_brew
then
  echo "  Installing Homebrew for you."

  # Install the correct homebrew for each OS type
  if test "$(uname)" = "Darwin"
  then
    # Run Homebrew installer (will prompt for password if needed)
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Export PATH for subsequent scripts in this session
    if test -f "/opt/homebrew/bin/brew"
    then
      export PATH="/opt/homebrew/bin:$PATH"
      echo "  Homebrew installed at /opt/homebrew"
    elif test -f "/usr/local/bin/brew"
    then
      export PATH="/usr/local/bin:$PATH"
      echo "  Homebrew installed at /usr/local"
    fi
  elif test "$(expr substr $(uname -s) 1 5)" = "Linux"
  then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Export PATH for Linux
    if test -d /home/linuxbrew/.linuxbrew; then
      export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
      echo "  Homebrew installed at /home/linuxbrew/.linuxbrew"
    fi
  fi
fi

exit 0
