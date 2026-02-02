#!/bin/bash
# MacScan - Uninstaller
# Removes MacScan from the system

set -euo pipefail

# =============================================================================
# Colors
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
GRAY='\033[0;90m'
NC='\033[0m'

ICON_SUCCESS="✓"
ICON_ERROR="✗"
ICON_WARNING="⚠"
ICON_INFO="ℹ"

log_success() { echo -e "${GREEN}${ICON_SUCCESS}${NC} $1"; }
log_error() { echo -e "${RED}${ICON_ERROR}${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}${ICON_WARNING}${NC} $1"; }
log_info() { echo -e "${BLUE}${ICON_INFO}${NC} $1"; }

# =============================================================================
# Configuration
# =============================================================================

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="${HOME}/.config/macscan"
DATA_DIR="${HOME}/.local/share/macscan"
CACHE_DIR="${HOME}/.cache/macscan"

# =============================================================================
# Helper Functions
# =============================================================================

needs_sudo() {
    [[ -e "$INSTALL_DIR" ]] && [[ ! -w "$INSTALL_DIR" ]]
}

maybe_sudo() {
    if needs_sudo; then
        sudo "$@"
    else
        "$@"
    fi
}

confirm() {
    local message="$1"
    local response
    
    echo -e "${YELLOW}${ICON_WARNING}${NC} ${message}"
    read -r -p "  Continue? [y/N] " response
    
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# =============================================================================
# Uninstall Functions
# =============================================================================

remove_binaries() {
    echo ""
    echo -e "${BOLD}Removing binaries...${NC}"
    echo ""
    
    if needs_sudo; then
        log_info "Admin access required for ${INSTALL_DIR}"
    fi
    
    # Remove macscan
    if [[ -f "${INSTALL_DIR}/macscan" ]]; then
        read -r -p "  Remove ${INSTALL_DIR}/macscan? [y/N] " response
        if [[ "$response" =~ ^[yY]$ ]]; then
            if maybe_sudo rm -f "${INSTALL_DIR}/macscan"; then
                log_success "Removed ${INSTALL_DIR}/macscan"
            else
                log_error "Failed to remove macscan"
            fi
        else
            log_info "Kept ${INSTALL_DIR}/macscan"
        fi
    else
        log_info "macscan not found in ${INSTALL_DIR}"
    fi
    
    # Remove ms alias
    if [[ -f "${INSTALL_DIR}/ms" ]]; then
        read -r -p "  Remove ${INSTALL_DIR}/ms? [y/N] " response
        if [[ "$response" =~ ^[yY]$ ]]; then
            if maybe_sudo rm -f "${INSTALL_DIR}/ms"; then
                log_success "Removed ${INSTALL_DIR}/ms"
            else
                log_error "Failed to remove ms"
            fi
        else
            log_info "Kept ${INSTALL_DIR}/ms"
        fi
    else
        log_info "ms not found in ${INSTALL_DIR}"
    fi
}

remove_config() {
    echo ""
    echo -e "${BOLD}Removing configuration...${NC}"
    echo ""
    
    if [[ -d "$CONFIG_DIR" ]]; then
        # Validate path contains macscan
        if [[ "$CONFIG_DIR" != *"macscan"* ]]; then
            log_error "Invalid config directory path, skipping"
            return 1
        fi
        
        read -r -p "  Remove configuration directory ($CONFIG_DIR)? [y/N] " response
        if [[ "$response" =~ ^[yY]$ ]]; then
            if rm -rf "$CONFIG_DIR"; then
                log_success "Removed $CONFIG_DIR"
            else
                log_error "Failed to remove config directory"
            fi
        else
            log_info "Kept $CONFIG_DIR"
        fi
    else
        log_info "Config directory not found"
    fi
}

remove_data() {
    echo ""
    echo -e "${BOLD}Removing data...${NC}"
    echo ""
    
    if [[ -d "$DATA_DIR" ]]; then
        # Validate path contains macscan
        if [[ "$DATA_DIR" != *"macscan"* ]]; then
            log_error "Invalid data directory path, skipping"
            return 1
        fi
        
        read -r -p "  Remove data directory ($DATA_DIR)? [y/N] " response
        if [[ "$response" =~ ^[yY]$ ]]; then
            if rm -rf "$DATA_DIR"; then
                log_success "Removed $DATA_DIR"
            else
                log_error "Failed to remove data directory"
            fi
        else
            log_info "Kept $DATA_DIR"
        fi
    else
        log_info "Data directory not found"
    fi
}

remove_cache() {
    echo ""
    echo -e "${BOLD}Removing cache...${NC}"
    echo ""
    
    if [[ -d "$CACHE_DIR" ]]; then
        # Validate path contains macscan
        if [[ "$CACHE_DIR" != *"macscan"* ]]; then
            log_error "Invalid cache directory path, skipping"
            return 1
        fi
        
        read -r -p "  Remove cache directory ($CACHE_DIR)? [y/N] " response
        if [[ "$response" =~ ^[yY]$ ]]; then
            if rm -rf "$CACHE_DIR"; then
                log_success "Removed $CACHE_DIR"
            else
                log_error "Failed to remove cache directory"
            fi
        else
            log_info "Kept $CACHE_DIR"
        fi
    else
        log_info "Cache directory not found"
    fi
}

show_completion() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${ICON_SUCCESS}${NC} ${BOLD}MacScan has been uninstalled${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GRAY}ClamAV was not removed. To remove it:${NC}"
    echo -e "  ${CYAN}brew uninstall clamav${NC}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo -e "  ${BOLD}${RED}🛡️  MacScan Uninstaller${NC}"
    echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo "  This will remove:"
    echo ""
    echo -e "  ${GRAY}•${NC} ${INSTALL_DIR}/macscan"
    echo -e "  ${GRAY}•${NC} ${INSTALL_DIR}/ms"
    echo -e "  ${GRAY}•${NC} ${CONFIG_DIR}"
    echo -e "  ${GRAY}•${NC} ${DATA_DIR}"
    echo -e "  ${GRAY}•${NC} ${CACHE_DIR}"
    echo ""
    
    if ! confirm "Are you sure you want to uninstall MacScan?"; then
        echo ""
        log_info "Uninstall cancelled"
        exit 0
    fi
    
    remove_binaries
    remove_config
    remove_data
    remove_cache
    show_completion
}

main "$@"
