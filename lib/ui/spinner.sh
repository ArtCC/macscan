#!/bin/bash
# MacScan - Spinner animations
# Loading spinners and animated indicators

# Prevent multiple sourcing
[[ -n "${_MACSCAN_SPINNER_LOADED:-}" ]] && return 0
readonly _MACSCAN_SPINNER_LOADED=1

# =============================================================================
# Spinner Configurations
# =============================================================================

# Spinner styles
readonly SPINNER_DOTS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
readonly SPINNER_LINE=("-" "\\" "|" "/")
readonly SPINNER_CIRCLE=("◐" "◓" "◑" "◒")
readonly SPINNER_BOUNCE=("⠁" "⠂" "⠄" "⠂")
readonly SPINNER_ARROW=("←" "↖" "↑" "↗" "→" "↘" "↓" "↙")

# Default spinner
SPINNER_CHARS=("${SPINNER_DOTS[@]}")
SPINNER_DELAY=0.08

# Spinner state
_SPINNER_PID=""
_SPINNER_MSG=""

# =============================================================================
# Spinner Functions
# =============================================================================

# Set spinner style
# Usage: set_spinner_style "dots|line|circle|bounce|arrow"
set_spinner_style() {
    local style="$1"
    case "$style" in
        dots)    SPINNER_CHARS=("${SPINNER_DOTS[@]}") ;;
        line)    SPINNER_CHARS=("${SPINNER_LINE[@]}") ;;
        circle)  SPINNER_CHARS=("${SPINNER_CIRCLE[@]}") ;;
        bounce)  SPINNER_CHARS=("${SPINNER_BOUNCE[@]}") ;;
        arrow)   SPINNER_CHARS=("${SPINNER_ARROW[@]}") ;;
        *)       SPINNER_CHARS=("${SPINNER_DOTS[@]}") ;;
    esac
}

# Start spinner with message
# Usage: start_spinner "Loading..."
start_spinner() {
    local msg="${1:-Loading...}"
    _SPINNER_MSG="$msg"
    
    # Don't start if not in a terminal
    [[ ! -t 1 ]] && {
        echo -e "${BLUE}|${NC} $msg"
        return
    }
    
    # Kill existing spinner if any
    stop_spinner 2>/dev/null
    
    hide_cursor
    
    # Start spinner in background with proper signal handling
    (
        # Trap to ensure clean exit
        trap 'exit 0' TERM INT HUP
        
        local i=0
        local len=${#SPINNER_CHARS[@]}
        while true; do
            local char="${SPINNER_CHARS[$((i % len))]}"
            printf "\r  ${CYAN}%s${NC} %s" "$char" "$msg"
            ((i++))
            sleep "$SPINNER_DELAY"
        done
    ) &
    
    _SPINNER_PID=$!
    disown $_SPINNER_PID 2>/dev/null
}

# Stop spinner
# Usage: stop_spinner
stop_spinner() {
    if [[ -n "$_SPINNER_PID" ]]; then
        # Send TERM signal and wait briefly
        kill -TERM "$_SPINNER_PID" 2>/dev/null || true
        sleep 0.1
        # Force kill if still running
        kill -9 "$_SPINNER_PID" 2>/dev/null || true
        wait "$_SPINNER_PID" 2>/dev/null || true
        _SPINNER_PID=""
    fi
    
    # Clear the line
    printf "\r\033[K"
    show_cursor
}

# Stop spinner with success message
# Usage: stop_spinner_success "Done!"
stop_spinner_success() {
    local msg="${1:-Done}"
    stop_spinner
    log_success "$msg"
}

# Stop spinner with error message
# Usage: stop_spinner_error "Failed!"
stop_spinner_error() {
    local msg="${1:-Failed}"
    stop_spinner
    log_error "$msg"
}

# Stop spinner with warning message
# Usage: stop_spinner_warning "Warning!"
stop_spinner_warning() {
    local msg="${1:-Warning}"
    stop_spinner
    log_warning "$msg"
}

# Inline spinner (doesn't use background process)
# Usage: spin_once; do_something; spin_once; ...
_INLINE_SPINNER_IDX=0
spin_once() {
    local msg="${1:-}"
    local len=${#SPINNER_CHARS[@]}
    local char="${SPINNER_CHARS[$((_INLINE_SPINNER_IDX % len))]}"
    
    printf "\r  ${CYAN}%s${NC} %s" "$char" "$msg"
    ((_INLINE_SPINNER_IDX++))
}

# Reset inline spinner
reset_inline_spinner() {
    _INLINE_SPINNER_IDX=0
}

# =============================================================================
# Status Indicators
# =============================================================================

# Show a pulsing dot indicator
# Usage: pulse_dot
pulse_dot() {
    local colors=("${GRAY}" "${WHITE}" "${CYAN}" "${WHITE}")
    local i=0
    local len=${#colors[@]}
    
    while true; do
        printf "\r  ${colors[$((i % len))]}●${NC} "
        ((i++))
        sleep 0.2
    done
}

# Show status with icon
# Usage: show_status "file.txt" "scanning|clean|threat"
show_status() {
    local item="$1"
    local status="$2"
    
    # Truncate long filenames
    local max_len=40
    if [[ ${#item} -gt $max_len ]]; then
        item="...${item: -$((max_len-3))}"
    fi
    
    case "$status" in
        scanning)
            printf "\r  ${CYAN}⠋${NC} %-45s ${GRAY}Scanning...${NC}" "$item"
            ;;
        clean)
            printf "\r  ${GREEN}${ICON_SUCCESS}${NC} %-45s ${GREEN}Clean${NC}\n" "$item"
            ;;
        threat)
            printf "\r  ${RED}${ICON_ERROR}${NC} %-45s ${RED}Threat${NC}\n" "$item"
            ;;
        skipped)
            printf "\r  ${GRAY}${ICON_ARROW}${NC} %-45s ${GRAY}Skipped${NC}\n" "$item"
            ;;
        *)
            printf "\r  ${GRAY}${ICON_BULLET}${NC} %-45s\n" "$item"
            ;;
    esac
}
