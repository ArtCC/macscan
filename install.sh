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
GRAY='\033[0;90m'
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

# Check if Homebrew is installed
check_homebrew() {
    if command -v brew &> /dev/null; then
        return 0
    fi
    return 1
}

# Offer to install Homebrew
install_homebrew_prompt() {
    echo ""
    echo -e "${BOLD}${CYAN}📦 Homebrew Not Found${NC}"
    echo ""
    echo "  Homebrew is the most popular package manager for macOS."
    echo "  It allows you to easily install software from the terminal."
    echo "  MacScan uses it to install ClamAV (the antivirus engine)."
    echo ""
    echo -n "  Would you like to install Homebrew now? [y/N]: "
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        log_info "Installing Homebrew..."
        echo ""
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Check if installation succeeded
        if command -v brew &> /dev/null; then
            log_success "Homebrew installed successfully"
            return 0
        else
            # Try to add to PATH for Apple Silicon
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
                log_success "Homebrew installed successfully"
                return 0
            fi
            log_error "Homebrew installation may have failed"
            return 1
        fi
    else
        echo ""
        log_info "Skipping Homebrew installation"
        echo ""
        echo "  To install Homebrew manually, run:"
        echo -e "  ${CYAN}/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
        echo ""
        echo "  Or visit: https://brew.sh"
        echo ""
        return 1
    fi
}

# Configure ClamAV after installation
configure_clamav() {
    log_info "Configuring ClamAV..."
    
    # Detect Homebrew prefix (Apple Silicon vs Intel)
    local brew_prefix
    if [[ -d "/opt/homebrew" ]]; then
        brew_prefix="/opt/homebrew"
    else
        brew_prefix="/usr/local"
    fi
    
    local clamav_etc="${brew_prefix}/etc/clamav"
    local freshclam_conf="${clamav_etc}/freshclam.conf"
    local freshclam_sample="${clamav_etc}/freshclam.conf.sample"
    
    # Create freshclam.conf from sample if it doesn't exist
    if [[ ! -f "$freshclam_conf" ]] && [[ -f "$freshclam_sample" ]]; then
        cp "$freshclam_sample" "$freshclam_conf"
        # Comment out the Example line (required for freshclam to work)
        sed -i '' 's/^Example/#Example/' "$freshclam_conf"
        log_success "ClamAV configured"
    elif [[ -f "$freshclam_conf" ]]; then
        log_success "ClamAV already configured"
    else
        log_warning "Could not find freshclam.conf.sample"
        echo -e "  ${GRAY}You may need to configure ClamAV manually${NC}"
    fi
}

# Check and offer to install ClamAV
check_and_install_clamav() {
    if command -v clamscan &> /dev/null; then
        log_success "ClamAV installed"
        # Also ensure it's configured
        configure_clamav
        return 0
    fi
    
    echo ""
    echo -e "${BOLD}${CYAN}🛡️ ClamAV Not Found${NC}"
    echo ""
    echo "  ClamAV is an open-source antivirus engine that MacScan uses"
    echo "  to detect malware, viruses, and other threats on your system."
    echo ""
    echo -e "  ${RED}ClamAV is required for MacScan to work.${NC}"
    echo ""
    
    # Check if Homebrew is available
    if ! check_homebrew; then
        log_error "Homebrew is required to install ClamAV"
        echo ""
        echo "  Please install Homebrew first, then run this installer again."
        echo ""
        echo "  Or install ClamAV manually:"
        echo "  1. Download from: https://www.clamav.net/downloads"
        echo "  2. Follow the official installation guide"
        echo "  3. Run this installer again"
        echo ""
        exit 1
    fi
    
    echo -n "  Would you like to install ClamAV with Homebrew now? [Y/n]: "
    read -r response
    
    # Default to Yes if empty
    if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
        echo ""
        log_info "Installing ClamAV..."
        echo ""
        
        if brew install clamav; then
            echo ""
            log_success "ClamAV installed successfully"
            
            # Configure ClamAV (required for freshclam to work)
            configure_clamav
            
            echo ""
            echo -e "  ${GRAY}Remember to run 'ms update' after installation${NC}"
            echo -e "  ${GRAY}to initialize the virus database.${NC}"
            return 0
        else
            log_error "Failed to install ClamAV"
            echo ""
            echo "  Please try installing manually:"
            echo -e "  ${CYAN}brew install clamav${NC}"
            echo ""
            exit 1
        fi
    else
        echo ""
        log_error "ClamAV is required for MacScan to work"
        echo ""
        echo "  Installation cancelled."
        echo ""
        echo "  To install later, first install ClamAV:"
        echo -e "  ${CYAN}brew install clamav${NC}"
        echo ""
        echo "  Then run this installer again."
        echo ""
        exit 1
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
    
    # Check Bash version (3.2+ required, which is macOS default)
    local bash_version="${BASH_VERSION%%.*}"
    if [[ $bash_version -lt 3 ]]; then
        log_error "Bash 3.2+ required (current: $BASH_VERSION)"
        exit 1
    fi
    log_success "Bash $BASH_VERSION"
    
    # Check Homebrew
    if check_homebrew; then
        log_success "Homebrew installed"
    else
        install_homebrew_prompt
    fi
    
    # Check ClamAV
    check_and_install_clamav
    
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
    
    # Install ms alias (with conflict check)
    local install_ms=1
    if [[ -e "${INSTALL_DIR}/ms" ]]; then
        # Check if it's our own ms from a previous install
        if grep -q "macscan" "${INSTALL_DIR}/ms" 2>/dev/null; then
            log_info "Updating existing ms alias"
        else
            echo ""
            log_warning "Another 'ms' command already exists at ${INSTALL_DIR}/ms"
            echo ""
            echo -n "  Overwrite it? [y/N]: "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                log_info "Overwriting existing ms command"
            else
                log_info "Skipping ms alias installation"
                install_ms=0
                echo "         You can use 'macscan' command instead"
            fi
        fi
    elif command -v ms &> /dev/null; then
        local existing_ms
        existing_ms=$(command -v ms)
        if [[ "$existing_ms" != "${INSTALL_DIR}/ms" ]]; then
            echo ""
            log_warning "Another 'ms' command exists: $existing_ms"
            echo ""
            echo -n "  Install our 'ms' alias anyway? [y/N]: "
            read -r response
            if [[ ! "$response" =~ ^[Yy]$ ]]; then
                log_info "Skipping ms alias installation"
                install_ms=0
                echo "         You can use 'macscan' command instead"
            fi
        fi
    fi
    
    if [[ $install_ms -eq 1 ]]; then
        if maybe_sudo cp "${SCRIPT_DIR}/bin/ms" "${INSTALL_DIR}/ms"; then
            maybe_sudo chmod +x "${INSTALL_DIR}/ms"
            log_success "Installed ms alias to ${INSTALL_DIR}"
        else
            log_error "Failed to install ms alias"
            exit 1
        fi
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
    
    # Offer to initialize virus database
    echo -e "  ${BOLD}Initialize virus database${NC}"
    echo ""
    echo "  The virus database needs to be downloaded before scanning."
    echo "  This may take a few minutes on the first run."
    echo ""
    echo -n "  Would you like to initialize the database now? [Y/n]: "
    read -r response
    
    if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
        echo ""
        log_info "Initializing virus database..."
        echo ""
        if freshclam 2>&1; then
            echo ""
            log_success "Virus database initialized"
        else
            log_warning "Database initialization had issues"
            echo -e "  ${GRAY}Try running 'ms update' manually later${NC}"
        fi
        echo ""
    else
        echo ""
        log_info "Skipping database initialization"
        echo ""
        echo -e "  ${YELLOW}${ICON_WARNING}${NC} Remember to initialize the database before scanning:"
        echo -e "    ${CYAN}ms update${NC}"
        echo ""
    fi
    
    echo "  Quick start:"
    echo ""
    echo -e "    ${CYAN}ms${NC}                         # Interactive menu"
    echo -e "    ${CYAN}ms scan${NC}                    # Quick scan"
    echo -e "    ${CYAN}ms scan --path ~/Downloads${NC} # Scan folder"
    echo -e "    ${CYAN}ms scan --full${NC}             # Full system scan"
    echo -e "    ${CYAN}ms help${NC}                    # Show help"
    echo ""
    
    # Shell completions info
    echo -e "  ${GRAY}Shell completions (optional):${NC}"
    echo ""
    echo -e "    ${GRAY}Bash:${NC} source ~/.config/macscan/completions/macscan.bash"
    echo -e "    ${GRAY}Zsh:${NC}  fpath=(~/.config/macscan/completions \$fpath)"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    # Clear terminal for clean look
    clear
    
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
