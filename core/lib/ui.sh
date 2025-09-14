#!/usr/bin/env bash
#
# Unified UI Library for Dotfiles System
# Provides consistent output formatting across all commands
#
# Style Guide:
# - Headers: Bold with optional emoji, used for major sections
# - Info: › prefix for general information
# - Success: ✓ prefix for successful operations
# - Warning: ⚠ prefix for warnings
# - Error: ✗ prefix for errors
# - Progress: ⟳ prefix for ongoing operations
# - Question: ? prefix for user prompts
# - Lists: Properly indented with • bullets
# - Sections: Clear visual separation between sections
#

# Detect terminal capabilities
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    # Terminal supports colors
    BOLD=$(tput bold 2>/dev/null || echo '')
    DIM=$(tput dim 2>/dev/null || echo '')
    RESET=$(tput sgr0 2>/dev/null || echo '')
    RED=$(tput setaf 1 2>/dev/null || echo '')
    GREEN=$(tput setaf 2 2>/dev/null || echo '')
    YELLOW=$(tput setaf 3 2>/dev/null || echo '')
    ORANGE=$(tput setaf 3 2>/dev/null || echo '')  # Most terminals show 3 as yellow/orange
    BLUE=$(tput setaf 4 2>/dev/null || echo '')
    MAGENTA=$(tput setaf 5 2>/dev/null || echo '')
    CYAN=$(tput setaf 6 2>/dev/null || echo '')
else
    # No color support
    BOLD=''
    DIM=''
    RESET=''
    RED=''
    GREEN=''
    YELLOW=''
    ORANGE=''
    BLUE=''
    MAGENTA=''
    CYAN=''
fi

# Unicode symbols (with fallbacks for limited terminals)
if [[ "${TERM:-}" == "xterm-256color" ]] || [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    CHECK="✓"
    CROSS="✗"
    WARN="!"  # Orange exclamation mark (will be colored orange)
    INFO="›"
    PROGRESS="⟳"
    QUESTION="?"
    BULLET="•"
    ARROW="→"
else
    # Fallback to ASCII
    CHECK="[OK]"
    CROSS="[FAIL]"
    WARN="[!]"
    INFO=">"
    PROGRESS="..."
    QUESTION="?"
    BULLET="*"
    ARROW="->"
fi

# Section header (major sections with optional emoji)
# Usage: header "🔧 Installation"
header() {
    local text="$1"
    echo ""
    echo "${BOLD}${text}${RESET}"
    echo "${DIM}$(printf '%.0s─' {1..60})${RESET}"
}

# Sub-header (minor sections)
# Usage: subheader "Configuration Files"
subheader() {
    local text="$1"
    echo ""
    echo "${BOLD}${text}${RESET}"
}

# Info message (general information)
# Usage: info "Processing files..."
info() {
    echo "${INFO} $1"
}

# Success message (successful operations)
# Usage: success "Installation complete"
success() {
    echo "${GREEN}${CHECK}${RESET} $1"
}

# Warning message (non-critical issues)
# Usage: warning "Config file missing, using defaults"
warning() {
    echo "${ORANGE}${WARN}${RESET} ${ORANGE}$1${RESET}"
}

# Error message (critical failures)
# Usage: error "Failed to create symlink"
error() {
    echo "${RED}${CROSS}${RESET} ${RED}$1${RESET}" >&2
}

# Progress indicator (ongoing operations)
# Usage: progress "Installing dependencies"
progress() {
    echo "${CYAN}${PROGRESS}${RESET} ${CYAN}$1${RESET}"
}

# User prompt (questions requiring input)
# Usage: prompt "Continue with installation?"
prompt() {
    echo -n "${MAGENTA}${QUESTION}${RESET} ${BOLD}$1${RESET} "
}

# List item (for displaying lists)
# Usage: list_item "homebrew"
list_item() {
    echo "  ${BULLET} $1"
}

# Indented info (for nested information)
# Usage: indent "Details about the operation"
indent() {
    local level="${2:-1}"
    local padding=""
    for ((i=0; i<level; i++)); do
        padding="  ${padding}"
    done
    echo "${padding}$1"
}

# Key-value display (for configuration display)
# Usage: key_value "Path" "/usr/local/bin"
key_value() {
    local key="$1"
    local value="$2"
    printf "  %-20s %s %s\n" "${key}:" "${ARROW}" "${value}"
}

# Section separator (visual break between sections)
# Usage: separator
separator() {
    echo "${DIM}$(printf '%.0s─' {1..60})${RESET}"
}

# Blank line (for spacing)
# Usage: blank
blank() {
    echo ""
}

# Status indicator with color based on status
# Usage: status "Service" "running"
status() {
    local name="$1"
    local state="$2"
    
    case "$state" in
        running|active|enabled|healthy|ok|success)
            echo "  ${GREEN}${CHECK}${RESET} ${name}: ${GREEN}${state}${RESET}"
            ;;
        stopped|inactive|disabled|degraded|warning)
            echo "  ${YELLOW}${WARN}${RESET} ${name}: ${YELLOW}${state}${RESET}"
            ;;
        error|failed|critical|missing)
            echo "  ${RED}${CROSS}${RESET} ${name}: ${RED}${state}${RESET}"
            ;;
        *)
            echo "  ${INFO} ${name}: ${state}"
            ;;
    esac
}

# Progress bar for long operations
# Usage: show_progress 50 100 "Processing"
show_progress() {
    local current="$1"
    local total="$2"
    local label="${3:-Progress}"
    local percentage=$((current * 100 / total))
    local bar_width=30
    local filled=$((percentage * bar_width / 100))
    
    printf "\r${INFO} %s: [" "$label"
    printf "%${filled}s" | tr ' ' '='
    printf "%$((bar_width - filled))s" | tr ' ' '-'
    printf "] %3d%%" "$percentage"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Summary display (for command completion)
# Usage: summary "Installation" 10 2 1
summary() {
    local title="$1"
    local success_count="${2:-0}"
    local warning_count="${3:-0}"
    local error_count="${4:-0}"
    
    separator
    echo ""
    echo "${BOLD}${title} Summary${RESET}"
    blank
    
    [[ $success_count -gt 0 ]] && echo "  ${GREEN}${CHECK}${RESET} Success: ${success_count}"
    [[ $warning_count -gt 0 ]] && echo "  ${YELLOW}${WARN}${RESET} Warnings: ${warning_count}"
    [[ $error_count -gt 0 ]] && echo "  ${RED}${CROSS}${RESET} Errors: ${error_count}"
    
    blank
}

# Spinner for unknown duration operations
# Usage: spinner & spinner_pid=$! ; do_work ; kill $spinner_pid
spinner() {
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    while :; do
        for ((i=0; i<${#spinstr}; i++)); do
            printf "\r${CYAN}%s${RESET} " "${spinstr:$i:1}"
            sleep 0.1
        done
    done
}

# Debug output (only shown when DEBUG is set)
# Usage: debug "Variable value: $var"
debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "${DIM}[DEBUG] $1${RESET}" >&2
    fi
}

# Table header
# Usage: table_header "Name" "Status" "Path"
table_header() {
    local cols=("$@")
    blank
    printf "  ${BOLD}"
    for col in "${cols[@]}"; do
        printf "%-20s " "$col"
    done
    printf "${RESET}\n"
    echo "  ${DIM}$(printf '%.0s─' {1..60})${RESET}"
}

# Table row
# Usage: table_row "git" "installed" "/usr/bin/git"
table_row() {
    local cols=("$@")
    printf "  "
    for col in "${cols[@]}"; do
        printf "%-20s " "$col"
    done
    printf "\n"
}

# Export all functions for use in other scripts
export -f header subheader info success warning error progress prompt
export -f list_item indent key_value separator blank status
export -f show_progress summary spinner debug table_header table_row