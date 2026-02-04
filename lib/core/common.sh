#!/bin/bash
# MacScan - Common utilities and helpers
# Global variables, configuration, and utility functions

# Prevent multiple sourcing
[[ -n "${_MACSCAN_COMMON_LOADED:-}" ]] && return 0
readonly _MACSCAN_COMMON_LOADED=1

# =============================================================================
# Version and App Info
# =============================================================================

readonly MACSCAN_VERSION="0.0.4"
readonly MACSCAN_NAME="MacScan"
readonly MACSCAN_DESCRIPTION="Command-line malware scanner for macOS"

# =============================================================================
# Directory Paths (XDG-compliant)
# =============================================================================

# Installation directory for binaries
readonly INSTALL_DIR="/usr/local/bin"

# Configuration directory
readonly CONFIG_DIR="${HOME}/.config/macscan"

# Data directory (persistent data)
readonly DATA_DIR="${HOME}/.local/share/macscan"

# Cache directory (temporary/regenerable data)
readonly CACHE_DIR="${HOME}/.cache/macscan"

# Quarantine directory
readonly QUARANTINE_DIR="${DATA_DIR}/quarantine"

# Logs directory
readonly LOGS_DIR="${DATA_DIR}/logs"

# =============================================================================
# Configuration Files
# =============================================================================

readonly CONFIG_FILE="${CONFIG_DIR}/config.conf"
readonly WHITELIST_FILE="${CONFIG_DIR}/whitelist"
readonly LAST_SCAN_FILE="${CACHE_DIR}/last_scan"

# =============================================================================
# Default Configuration Values
# =============================================================================

# These can be overridden in config.conf
MACSCAN_VERBOSE=0
MACSCAN_AUTO_UPDATE=0
MACSCAN_NOTIFY=0
MACSCAN_QUARANTINE_AUTO=0
MACSCAN_DB_MAX_AGE=7  # Days before warning about outdated DB

# =============================================================================
# Default Scan Paths
# =============================================================================

readonly DEFAULT_SCAN_PATHS=(
    "${HOME}/Downloads"
    "${HOME}/Desktop"
    "${HOME}/Documents"
    "${HOME}/Applications"
    "/Applications"
)

readonly FULL_SCAN_PATHS=(
    "${HOME}"
    "/Applications"
    "/Library"
    "/usr/local"
)

# =============================================================================
# ClamAV Configuration
# =============================================================================

# Detect ClamAV database path based on architecture (Intel vs Apple Silicon)
if [[ "$(uname -m)" == "arm64" ]]; then
    readonly CLAMAV_DB_PATH="/opt/homebrew/var/lib/clamav"
else
    readonly CLAMAV_DB_PATH="/usr/local/var/lib/clamav"
fi
readonly CLAMAV_SCAN_CMD="clamscan"
readonly CLAMAV_UPDATE_CMD="freshclam"

# =============================================================================
# Source Dependencies
# =============================================================================

# Get the directory where this script is located
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source colors module
source "${_COMMON_DIR}/colors.sh"

# =============================================================================
# Utility Functions
# =============================================================================

# Check if running on macOS
is_macos() {
    [[ "$OSTYPE" == "darwin"* ]]
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if ClamAV is installed
is_clamav_installed() {
    command_exists "$CLAMAV_SCAN_CMD"
}

# Check if ClamAV database is initialized
is_clamav_db_ready() {
    [[ -d "$CLAMAV_DB_PATH" ]] && [[ -n "$(ls -A "$CLAMAV_DB_PATH" 2>/dev/null)" ]]
}

# Get database age in days
get_db_age_days() {
    if [[ ! -d "$CLAMAV_DB_PATH" ]]; then
        echo "-1"
        return
    fi
    
    local latest
    latest=$(ls -t "$CLAMAV_DB_PATH"/*.cvd 2>/dev/null | head -n1)
    
    if [[ -z "$latest" ]]; then
        echo "-1"
        return
    fi
    
    # Get file modification time in epoch seconds
    local file_epoch
    file_epoch=$(stat -f "%m" "$latest" 2>/dev/null)
    local now_epoch
    now_epoch=$(date +%s)
    
    # Calculate days
    local diff_seconds=$((now_epoch - file_epoch))
    local diff_days=$((diff_seconds / 86400))
    
    echo "$diff_days"
}

# Check if database is outdated (returns 0 if outdated, 1 if OK)
is_db_outdated() {
    local age_days
    age_days=$(get_db_age_days)
    
    [[ $age_days -ge $MACSCAN_DB_MAX_AGE ]] || [[ $age_days -lt 0 ]]
}

# Show database age warning if needed
show_db_age_warning() {
    local age_days
    age_days=$(get_db_age_days)
    
    if [[ $age_days -lt 0 ]]; then
        return  # DB not initialized, handled elsewhere
    fi
    
    if [[ $age_days -ge $MACSCAN_DB_MAX_AGE ]]; then
        log_warning "Virus database is ${age_days} days old"
        echo -e "  ${GRAY}Run 'ms update' to get latest signatures${NC}"
        echo ""
    fi
}

# Create required directories
ensure_directories() {
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    mkdir -p "$DATA_DIR" 2>/dev/null || true
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    mkdir -p "$QUARANTINE_DIR" 2>/dev/null || true
    mkdir -p "$LOGS_DIR" 2>/dev/null || true
}

# Get current timestamp
get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Get current date for log files
get_date() {
    date "+%Y-%m-%d"
}

# Count files in a directory (recursive)
count_files() {
    local path="$1"
    local count=0
    
    if [[ -d "$path" ]]; then
        count=$(find "$path" -type f 2>/dev/null | wc -l | tr -d ' ')
    elif [[ -f "$path" ]]; then
        count=1
    fi
    
    echo "$count"
}

# Get directory size in bytes
get_dir_size() {
    local path="$1"
    if [[ -e "$path" ]]; then
        du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}'
    else
        echo 0
    fi
}

# Check if user has sudo access (without prompting)
has_sudo() {
    sudo -n true 2>/dev/null
}

# Check if path needs sudo to access
needs_sudo() {
    local path="$1"
    [[ ! -r "$path" ]]
}

# Safe file removal (checks for dangerous paths and asks confirmation)
# Usage: safe_rm "/path/to/remove" [skip_confirm]
safe_rm() {
    local path="$1"
    local skip_confirm="${2:-0}"
    
    # Refuse empty paths
    if [[ -z "$path" ]]; then
        log_error "Refusing to remove: empty path"
        return 1
    fi
    
    # Refuse to remove critical paths
    case "$path" in
        "/" | "/System" | "/System/"* | "/usr" | "/usr/"* | "/bin" | "/bin/"* | "/sbin" | "/sbin/"* | "$HOME" | "")
            log_error "Refusing to remove protected path: $path"
            return 1
            ;;
    esac
    
    # Must contain 'macscan' in path for extra safety
    if [[ "$path" != *"macscan"* ]]; then
        log_error "Refusing to remove path not related to macscan: $path"
        return 1
    fi
    
    if [[ -e "$path" ]]; then
        # Ask for confirmation unless skipped
        if [[ $skip_confirm -ne 1 ]]; then
            read -r -p "  Remove $path? [y/N] " response
            if [[ ! "$response" =~ ^[yY]$ ]]; then
                log_info "Skipped: $path"
                return 0
            fi
        fi
        rm -rf "$path"
    fi
}

# Read configuration value
# Usage: get_config "key" "default_value"
get_config() {
    local key="$1"
    local default="$2"
    
    if [[ -f "$CONFIG_FILE" ]]; then
        local value
        value=$(grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2-)
        echo "${value:-$default}"
    else
        echo "$default"
    fi
}

# Write configuration value
# Usage: set_config "key" "value"
set_config() {
    local key="$1"
    local value="$2"
    
    ensure_directories
    
    if [[ -f "$CONFIG_FILE" ]]; then
        # Remove existing key
        grep -v "^${key}=" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" 2>/dev/null || true
        mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
    
    # Add new key=value
    echo "${key}=${value}" >> "$CONFIG_FILE"
}

# Save last scan info
save_last_scan() {
    local path="$1"
    local files_scanned="$2"
    local threats_found="$3"
    local duration="$4"
    
    ensure_directories
    
    cat > "$LAST_SCAN_FILE" << EOF
timestamp=$(get_timestamp)
path=${path}
files_scanned=${files_scanned}
threats_found=${threats_found}
duration=${duration}
EOF
}

# Get last scan info
get_last_scan() {
    if [[ -f "$LAST_SCAN_FILE" ]]; then
        cat "$LAST_SCAN_FILE"
    else
        echo "No previous scan found"
    fi
}

# Write to log file
# Usage: write_log "message"
write_log() {
    local message="$1"
    local log_file="${LOGS_DIR}/macscan_$(get_date).log"
    
    ensure_directories
    echo "[$(get_timestamp)] $message" >> "$log_file"
}

# Cleanup old log files (keep last 30 days)
cleanup_old_logs() {
    if [[ -d "$LOGS_DIR" ]]; then
        find "$LOGS_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    fi
}

# Trap handler for cleanup
cleanup_on_exit() {
    show_cursor
    # Add any other cleanup tasks here
}

# Set up trap for clean exit
trap cleanup_on_exit EXIT INT TERM
