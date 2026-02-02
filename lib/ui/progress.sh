#!/bin/bash
# MacScan - Progress bar utilities
# Progress bars and completion indicators

# Prevent multiple sourcing
[[ -n "${_MACSCAN_PROGRESS_LOADED:-}" ]] && return 0
readonly _MACSCAN_PROGRESS_LOADED=1

# =============================================================================
# Progress Bar Configuration
# =============================================================================

# Progress bar characters
readonly PROGRESS_FILLED="█"
readonly PROGRESS_EMPTY="░"
readonly PROGRESS_PARTIAL="▓"

# Default width
PROGRESS_WIDTH=30
PROGRESS_MIN_WIDTH=10

# Get terminal width safely
get_terminal_width() {
    local width
    width=$(tput cols 2>/dev/null || echo 80)
    echo "$width"
}

# Calculate optimal progress bar width based on terminal size
get_optimal_progress_width() {
    local term_width
    term_width=$(get_terminal_width)
    
    # Reserve space for: "  " prefix + " 100%" + "  (12345/12345 files)" padding
    local reserved=45
    local available=$((term_width - reserved))
    
    if [[ $available -lt $PROGRESS_MIN_WIDTH ]]; then
        echo "$PROGRESS_MIN_WIDTH"
    elif [[ $available -gt $PROGRESS_WIDTH ]]; then
        echo "$PROGRESS_WIDTH"
    else
        echo "$available"
    fi
}

# =============================================================================
# Progress Bar Functions
# =============================================================================

# Draw a progress bar
# Usage: draw_progress_bar current total [width]
draw_progress_bar() {
    local current=$1
    local total=$2
    local width=${3:-$PROGRESS_WIDTH}
    
    # Avoid division by zero
    [[ $total -eq 0 ]] && total=1
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    [[ $percent -gt 100 ]] && percent=100
    
    # Calculate filled width
    local filled=$((width * current / total))
    [[ $filled -gt $width ]] && filled=$width
    
    # Build the bar
    local bar=""
    local i
    
    for ((i = 0; i < filled; i++)); do
        bar+="${PROGRESS_FILLED}"
    done
    
    for ((i = filled; i < width; i++)); do
        bar+="${PROGRESS_EMPTY}"
    done
    
    # Return the bar string
    echo -e "${CYAN}${bar}${NC}"
}

# Show progress with percentage
# Usage: show_progress current total "message" [width]
show_progress() {
    local current=$1
    local total=$2
    local message="${3:-}"
    local width=${4:-}
    
    # Auto-calculate width if not provided
    [[ -z "$width" ]] && width=$(get_optimal_progress_width)
    
    # Avoid division by zero
    [[ $total -eq 0 ]] && total=1
    
    local percent=$((current * 100 / total))
    [[ $percent -gt 100 ]] && percent=100
    
    local bar
    bar=$(draw_progress_bar "$current" "$total" "$width")
    
    # Format: [████████░░░░░░░░░░░░] 45% (123/456 files)
    printf "\r  %s %3d%%" "$bar" "$percent"
    
    if [[ -n "$message" ]]; then
        printf "  ${GRAY}%s${NC}" "$message"
    fi
    
    # Clear rest of line
    printf "\033[K"
}

# Show progress with file count
# Usage: show_scan_progress current total
show_scan_progress() {
    local current=$1
    local total=$2
    
    show_progress "$current" "$total" "(${current}/${total} files)"
}

# Complete the progress (show 100% and newline)
# Usage: complete_progress "message"
complete_progress() {
    local message="${1:-Complete}"
    local width=${PROGRESS_WIDTH}
    
    # Full bar
    local bar=""
    for ((i = 0; i < width; i++)); do
        bar+="${PROGRESS_FILLED}"
    done
    
    printf "\r  ${GREEN}%s${NC} 100%%  ${GREEN}%s${NC}\n" "$bar" "$message"
}

# =============================================================================
# Summary Statistics
# =============================================================================

# Show scan summary
# Usage: show_scan_summary files_scanned threats_found duration
show_scan_summary() {
    local files_scanned=$1
    local threats_found=$2
    local duration=$3
    
    local duration_formatted
    duration_formatted=$(format_duration "$duration")
    
    echo ""
    print_line 45
    
    if [[ $threats_found -eq 0 ]]; then
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} ${BOLD}Scan Complete${NC} - No threats found"
    else
        echo -e "  ${RED}${ICON_THREAT}${NC} ${BOLD}Scan Complete${NC} - ${RED}${threats_found} threat(s) found${NC}"
    fi
    
    echo ""
    echo -e "  ${GRAY}Scanned:${NC} ${files_scanned} files"
    echo -e "  ${GRAY}Threats:${NC} ${threats_found}"
    echo -e "  ${GRAY}Duration:${NC} ${duration_formatted}"
    
    print_line 45
    echo ""
}

# Show compact status line
# Usage: show_status_line files threats time
show_status_line() {
    local files=$1
    local threats=$2
    local time=$3
    
    local threat_color="${GREEN}"
    [[ $threats -gt 0 ]] && threat_color="${RED}"
    
    printf "\r  ${GRAY}Scanned:${NC} %d ${GRAY}|${NC} ${threat_color}Threats:${NC} %d ${GRAY}|${NC} ${GRAY}Time:${NC} %s" \
        "$files" "$threats" "$(format_duration "$time")"
}

# =============================================================================
# File Processing Display
# =============================================================================

# Show current file being scanned
# Usage: show_current_file "path/to/file"
show_current_file() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    
    # Truncate if too long
    local max_len=35
    if [[ ${#filename} -gt $max_len ]]; then
        filename="${filename:0:$((max_len-3))}..."
    fi
    
    printf "\r  ${CYAN}⠋${NC} %-40s" "$filename"
}

# Show scanned file result
# Usage: show_file_result "path/to/file" "clean|infected|error"
show_file_result() {
    local filepath="$1"
    local result="$2"
    local filename
    filename=$(basename "$filepath")
    
    # Truncate if too long
    local max_len=35
    if [[ ${#filename} -gt $max_len ]]; then
        filename="${filename:0:$((max_len-3))}..."
    fi
    
    case "$result" in
        clean)
            printf "\r  ${GREEN}${ICON_SUCCESS}${NC} %-40s ${GREEN}Clean${NC}\n" "$filename"
            ;;
        infected)
            printf "\r  ${RED}${ICON_ERROR}${NC} %-40s ${RED}Infected${NC}\n" "$filename"
            ;;
        error)
            printf "\r  ${YELLOW}${ICON_WARNING}${NC} %-40s ${YELLOW}Error${NC}\n" "$filename"
            ;;
        *)
            printf "\r  ${GRAY}${ICON_BULLET}${NC} %-40s ${GRAY}Unknown${NC}\n" "$filename"
            ;;
    esac
}

# =============================================================================
# Real-time Counter Display
# =============================================================================

# Global counters for live display
_SCAN_FILES_COUNT=0
_SCAN_THREATS_COUNT=0
_SCAN_START_TIME=0

# Initialize scan counters
init_scan_counters() {
    _SCAN_FILES_COUNT=0
    _SCAN_THREATS_COUNT=0
    _SCAN_START_TIME=$(date +%s)
}

# Increment file counter
increment_file_count() {
    ((_SCAN_FILES_COUNT++))
}

# Increment threat counter
increment_threat_count() {
    ((_SCAN_THREATS_COUNT++))
}

# Get current scan duration
get_scan_duration() {
    local now
    now=$(date +%s)
    echo $((now - _SCAN_START_TIME))
}

# Update live status display
update_live_status() {
    local current_file="${1:-}"
    local duration
    duration=$(get_scan_duration)
    
    # Line 1: Current file
    if [[ -n "$current_file" ]]; then
        show_current_file "$current_file"
    fi
    
    # Line 2: Stats
    printf "\n"
    show_status_line "$_SCAN_FILES_COUNT" "$_SCAN_THREATS_COUNT" "$duration"
    
    # Move cursor back up
    cursor_up 1
}
