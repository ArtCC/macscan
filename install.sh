#!/bin/bash
# MacScan - Installer
# Installs MacScan to the system

set -euo pipefail

# =============================================================================
# Colors (standalone - not using lib yet)
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
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

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Helper Functions
# =============================================================================

# Check if we need sudo for install directory
needs_sudo() {
    if [[ -e "$INSTALL_DIR" ]]; then
        [[ ! -w "$INSTALL_DIR" ]]
    else
        local parent_dir
        parent_dir="$(dirname "$INSTALL_DIR")"
        [[ ! -w "$parent_dir" ]]
    fi
}

# Run command with sudo if needed
maybe_sudo() {
    if needs_sudo; then
        sudo "$@"
    else
        "$@"
    fi
}

# Check system requirements
check_requirements() {
    echo ""
    echo -e "${BOLD}Checking requirements...${NC}"
    echo ""
    
    # Check macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "MacScan is designed for macOS only"
        exit 1
    fi
    log_success "macOS detected"
    
    # Check Bash version
    local bash_version="${BASH_VERSION%%.*}"
    if [[ $bash_version -lt 4 ]]; then
        log_warning "Bash 4+ recommended (current: $BASH_VERSION)"
        echo "         Install with: brew install bash"
    else
        log_success "Bash $BASH_VERSION"
    fi
    
    # Check ClamAV
    if command -v clamscan &> /dev/null; then
        log_success "ClamAV installed"
    else
        log_warning "ClamAV not installed"
        echo "         Install with: brew install clamav"
        echo "         Then run: ms update"
    fi
    
    # Check if source files exist
    if [[ ! -f "${SCRIPT_DIR}/bin/macscan" ]]; then
        log_error "Source files not found. Run installer from the macscan directory."
        exit 1
    fi
    log_success "Source files found"
}

# Create directory structure
create_directories() {
    echo ""
    echo -e "${BOLD}Creating directories...${NC}"
    echo ""
    
    # Create config directory
    if mkdir -p "$CONFIG_DIR" "$CONFIG_DIR/bin" "$CONFIG_DIR/lib"; then
        log_success "Config directory: $CONFIG_DIR"
    else
        log_error "Failed to create config directory"
        exit 1
    fi
    
    # Create data directory
    if mkdir -p "$DATA_DIR" "$DATA_DIR/quarantine" "$DATA_DIR/logs"; then
        log_success "Data directory: $DATA_DIR"
    else
        log_error "Failed to create data directory"
        exit 1
    fi
    
    # Create cache directory
    if mkdir -p "$CACHE_DIR"; then
        log_success "Cache directory: $CACHE_DIR"
    else
        log_error "Failed to create cache directory"
        exit 1
    fi
    
    # Create install directory if needed
    if [[ ! -d "$INSTALL_DIR" ]]; then
        if maybe_sudo mkdir -p "$INSTALL_DIR"; then
            log_success "Install directory: $INSTALL_DIR"
        else
            log_error "Failed to create install directory"
            exit 1
        fi
    fi
}

# Install files
install_files() {
    echo ""
    echo -e "${BOLD}Installing files...${NC}"
    echo ""
    
    # Copy library files
    if cp -r "${SCRIPT_DIR}/lib/"* "${CONFIG_DIR}/lib/"; then
        log_success "Installed library files"
    else
        log_error "Failed to install library files"
        exit 1
    fi
    
    # Copy bin files to config
    if cp -r "${SCRIPT_DIR}/bin/"* "${CONFIG_DIR}/bin/"; then
        chmod +x "${CONFIG_DIR}/bin/"*
        log_success "Installed bin files to config"
    else
        log_error "Failed to install bin files"
        exit 1
    fi
    
    # Install main binaries to /usr/local/bin
    if needs_sudo; then
        log_info "Admin access required for ${INSTALL_DIR}"
    fi
    
    # Install macscan
    if maybe_sudo cp "${SCRIPT_DIR}/bin/macscan" "${INSTALL_DIR}/macscan"; then
        maybe_sudo chmod +x "${INSTALL_DIR}/macscan"
        log_success "Installed macscan to ${INSTALL_DIR}"
    else
        log_error "Failed to install macscan"
        exit 1
    fi
    
    # Install ms alias
    if maybe_sudo cp "${SCRIPT_DIR}/bin/ms" "${INSTALL_DIR}/ms"; then
        maybe_sudo chmod +x "${INSTALL_DIR}/ms"
        log_success "Installed ms alias to ${INSTALL_DIR}"
    else
        log_error "Failed to install ms alias"
        exit 1
    fi
    
    # Copy install/uninstall scripts to config for later use
    cp "${SCRIPT_DIR}/install.sh" "${CONFIG_DIR}/" 2>/dev/null || true
    cp "${SCRIPT_DIR}/uninstall.sh" "${CONFIG_DIR}/" 2>/dev/null || true
    
    # Install shell completions
    if [[ -d "${SCRIPT_DIR}/completions" ]]; then
        mkdir -p "${CONFIG_DIR}/completions"
        cp -r "${SCRIPT_DIR}/completions/"* "${CONFIG_DIR}/completions/" 2>/dev/null || true
        log_success "Installed shell completions"
    fi
    
    # Create default whitelist if it doesn't exist
    if [[ ! -f "${CONFIG_DIR}/whitelist" ]]; then
        cat > "${CONFIG_DIR}/whitelist" << 'EOF'
# MacScan Whitelist
# Add paths to exclude from scanning (one per line)
# Lines starting with # are comments

# Example:
# /path/to/exclude
# ~/Library/Caches
EOF
        log_success "Created default whitelist"
    fi
    
    # Create default config if it doesn't exist
    if [[ ! -f "${CONFIG_DIR}/config.conf" ]]; then
        cat > "${CONFIG_DIR}/config.conf" << 'EOF'
# MacScan Configuration

# Show verbose output (0=off, 1=on)
verbose=0

# Auto-update database before scanning (0=off, 1=on)
auto_update=0

# Send macOS notifications (0=off, 1=on)
notify=0

# Auto-quarantine infected files (0=off, 1=on)
quarantine_auto=0

# Days before warning about outdated database
db_max_age=7
EOF
        log_success "Created default configuration"
    fi
}

# Verify installation
verify_installation() {
    echo ""
    echo -e "${BOLD}Verifying installation...${NC}"
    echo ""
    
    # Check if binaries are accessible
    if command -v macscan &> /dev/null; then
        log_success "macscan command available"
    else
        log_warning "macscan not in PATH"
        echo "         You may need to restart your terminal"
    fi
    
    if command -v ms &> /dev/null; then
        log_success "ms command available"
    else
        log_warning "ms not in PATH"
    fi
    
    # Test execution
    if "${INSTALL_DIR}/macscan" --version &> /dev/null; then
        log_success "Installation verified"
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

# Show post-install message
show_success() {
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}${ICON_SUCCESS}${NC} ${BOLD}MacScan installed successfully!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Quick start:"
    echo ""
    echo -e "    ${CYAN}ms scan${NC}                    # Quick scan"
    echo -e "    ${CYAN}ms scan --path ~/Downloads${NC} # Scan folder"
    echo -e "    ${CYAN}ms scan --full${NC}             # Full system scan"
    echo -e "    ${CYAN}ms scan --dry-run${NC}          # Preview scan"
    echo -e "    ${CYAN}ms update${NC}                  # Update virus database"
    echo -e "    ${CYAN}ms quarantine list${NC}         # View quarantine"
    echo -e "    ${CYAN}ms help${NC}                    # Show help"
    echo ""
    
    # Shell completions info
    echo "  Shell completions:"
    echo ""
    echo -e "    ${GRAY}Bash:${NC} source ~/.config/macscan/completions/macscan.bash"
    echo -e "    ${GRAY}Zsh:${NC}  fpath=(~/.config/macscan/completions \$fpath)"
    echo ""
    
    # ClamAV reminder
    if ! command -v clamscan &> /dev/null; then
        echo -e "  ${YELLOW}${ICON_WARNING}${NC} Don't forget to install ClamAV:"
        echo ""
        echo -e "    ${CYAN}brew install clamav${NC}"
        echo -e "    ${CYAN}ms update${NC}"
        echo ""
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo -e "  ${BOLD}${CYAN}🛡️  MacScan Installer${NC}"
    echo -e "  ${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    check_requirements
    create_directories
    install_files
    verify_installation
    show_success
}

main "$@"
