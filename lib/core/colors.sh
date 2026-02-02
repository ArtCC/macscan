#!/bin/bash
# MacScan - Colors and formatting
# ANSI color codes and text formatting utilities

# Prevent multiple sourcing
[[ -n "${_MACSCAN_COLORS_LOADED:-}" ]] && return 0
readonly _MACSCAN_COLORS_LOADED=1

# =============================================================================
# ANSI Color Codes
# =============================================================================

# Basic colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'

# Bold colors
readonly BOLD='\033[1m'
readonly BOLD_RED='\033[1;31m'
readonly BOLD_GREEN='\033[1;32m'
readonly BOLD_YELLOW='\033[1;33m'
readonly BOLD_BLUE='\033[1;34m'
readonly BOLD_PURPLE='\033[1;35m'
readonly BOLD_CYAN='\033[1;36m'

# Background colors
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'

# Reset
readonly NC='\033[0m'

# =============================================================================
# Icons/Symbols
# =============================================================================

readonly ICON_SUCCESS="✓"
readonly ICON_ERROR="✗"
readonly ICON_WARNING="⚠"
readonly ICON_INFO="ℹ"
readonly ICON_ARROW="→"
readonly ICON_BULLET="•"
readonly ICON_SHIELD="🛡️"
readonly ICON_SCAN="🔍"
readonly ICON_CLEAN="✨"
readonly ICON_THREAT="🚨"
readonly ICON_FOLDER="📁"
readonly ICON_FILE="📄"
readonly ICON_CLOCK="⏱"
readonly ICON_CHECK="☑"
readonly ICON_UNCHECK="☐"

# =============================================================================
# Formatting Functions
# =============================================================================

# Print colored text
# Usage: print_color "COLOR" "text"
print_color() {
    local color="$1"
    local text="$2"
    echo -e "${color}${text}${NC}"
}

# Print success message
# Usage: log_success "message"
log_success() {
    echo -e "${GREEN}${ICON_SUCCESS}${NC} $1"
}

# Print error message
# Usage: log_error "message"
log_error() {
    echo -e "${RED}${ICON_ERROR}${NC} $1" >&2
}

# Print warning message
# Usage: log_warning "message"
log_warning() {
    echo -e "${YELLOW}${ICON_WARNING}${NC} $1"
}

# Print info message
# Usage: log_info "message"
log_info() {
    echo -e "${BLUE}${ICON_INFO}${NC} $1"
}

# Print debug message (only if DEBUG=1)
# Usage: log_debug "message"
log_debug() {
    [[ "${MACSCAN_DEBUG:-0}" == "1" ]] && echo -e "${GRAY}[DEBUG] $1${NC}"
}

# Print header/title
# Usage: print_header "title"
print_header() {
    local title="$1"
    local width=${2:-50}
    local line=$(printf '─%.0s' $(seq 1 $width))
    echo ""
    echo -e "  ${BOLD}${title}${NC}"
    echo -e "  ${GRAY}${line}${NC}"
}

# Print a horizontal line
# Usage: print_line [width]
print_line() {
    local width=${1:-50}
    local line=$(printf '─%.0s' $(seq 1 $width))
    echo -e "  ${GRAY}${line}${NC}"
}

# Print app banner
# Usage: print_banner
print_banner() {
    echo ""
    echo -e "  ${BOLD_CYAN}${ICON_SHIELD}  MacScan${NC} ${GRAY}v${MACSCAN_VERSION:-0.1.0}${NC}"
    print_line 45
}

# Format file size for display (without bc dependency)
# Usage: format_size bytes
format_size() {
    local bytes=$1
    
    # Handle empty or non-numeric input
    [[ -z "$bytes" || ! "$bytes" =~ ^[0-9]+$ ]] && echo "0B" && return
    
    if [[ $bytes -ge 1073741824 ]]; then
        # GB - use awk instead of bc for portability
        awk "BEGIN {printf \"%.1fGB\", $bytes/1073741824}"
    elif [[ $bytes -ge 1048576 ]]; then
        # MB
        awk "BEGIN {printf \"%.1fMB\", $bytes/1048576}"
    elif [[ $bytes -ge 1024 ]]; then
        # KB
        awk "BEGIN {printf \"%.1fKB\", $bytes/1024}"
    else
        printf "%dB" "$bytes"
    fi
}

# Format time duration
# Usage: format_duration seconds
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    if [[ $hours -gt 0 ]]; then
        printf "%02d:%02d:%02d" $hours $minutes $secs
    else
        printf "%02d:%02d" $minutes $secs
    fi
}

# Show/hide cursor
show_cursor() {
    printf '\033[?25h'
}

hide_cursor() {
    printf '\033[?25l'
}

# Clear current line
clear_line() {
    printf '\r\033[K'
}

# Move cursor up N lines
cursor_up() {
    local lines=${1:-1}
    printf '\033[%dA' "$lines"
}

# Move cursor down N lines
cursor_down() {
    local lines=${1:-1}
    printf '\033[%dB' "$lines"
}
