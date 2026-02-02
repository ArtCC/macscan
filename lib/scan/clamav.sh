#!/bin/bash
# MacScan - ClamAV wrapper
# Interface with ClamAV for malware scanning

# Prevent multiple sourcing
[[ -n "${_MACSCAN_CLAMAV_LOADED:-}" ]] && return 0
readonly _MACSCAN_CLAMAV_LOADED=1

# =============================================================================
# Source Dependencies
# =============================================================================

_CLAMAV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_CLAMAV_DIR}/../core/common.sh"
source "${_CLAMAV_DIR}/../ui/spinner.sh"
source "${_CLAMAV_DIR}/../ui/progress.sh"

# =============================================================================
# Whitelist Support
# =============================================================================

# Build exclusion arguments from whitelist file
# Returns array of --exclude-dir arguments
build_exclusion_args() {
    local -a exclude_args=()
    
    if [[ -f "$WHITELIST_FILE" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            # Trim whitespace
            line="${line#"${line%%[![:space:]]*}"}"
            line="${line%"${line##*[![:space:]]}"}"
            [[ -n "$line" ]] && exclude_args+=("--exclude-dir=$line")
        done < "$WHITELIST_FILE"
    fi
    
    # Return the array elements (handle empty array)
    if [[ ${#exclude_args[@]} -gt 0 ]]; then
        printf '%s\n' "${exclude_args[@]}"
    fi
}

# Check if path is whitelisted
is_whitelisted() {
    local path="$1"
    
    [[ ! -f "$WHITELIST_FILE" ]] && return 1
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ "$path" == "$line"* ]] && return 0
    done < "$WHITELIST_FILE"
    
    return 1
}

# =============================================================================
# ClamAV Status Functions
# =============================================================================

# Check ClamAV installation status
check_clamav_status() {
    local status=0
    
    if ! is_clamav_installed; then
        log_error "ClamAV is not installed"
        echo ""
        echo "  Install ClamAV with:"
        echo -e "  ${CYAN}brew install clamav${NC}"
        echo ""
        return 1
    fi
    
    if ! is_clamav_db_ready; then
        log_warning "ClamAV virus database not initialized"
        echo ""
        echo "  Initialize the database with:"
        echo -e "  ${CYAN}ms update${NC}"
        echo ""
        return 2
    fi
    
    return 0
}

# Get ClamAV version
get_clamav_version() {
    if is_clamav_installed; then
        clamscan --version 2>/dev/null | head -n1
    else
        echo "Not installed"
    fi
}

# Get database info
get_db_info() {
    if [[ -d "$CLAMAV_DB_PATH" ]]; then
        local db_files
        db_files=$(ls -la "$CLAMAV_DB_PATH"/*.cvd 2>/dev/null | wc -l | tr -d ' ')
        
        if [[ $db_files -gt 0 ]]; then
            local latest
            latest=$(ls -t "$CLAMAV_DB_PATH"/*.cvd 2>/dev/null | head -n1)
            local mod_date
            mod_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$latest" 2>/dev/null)
            echo "Last updated: $mod_date"
        else
            echo "Database not initialized"
        fi
    else
        echo "Database directory not found"
    fi
}

# =============================================================================
# Database Update
# =============================================================================

# Update ClamAV virus database
update_database() {
    # Check ClamAV installation (but not DB - we're about to update it)
    if ! is_clamav_installed; then
        print_banner
        echo ""
        log_error "ClamAV is not installed"
        echo ""
        echo "  Install ClamAV first:"
        echo -e "  ${CYAN}brew install clamav${NC}"
        echo ""
        return 1
    fi
    
    print_banner
    echo ""
    log_info "Updating virus database..."
    echo ""
    
    start_spinner "Downloading latest signatures..."
    
    # Run freshclam
    local output
    local exit_code
    
    output=$(freshclam 2>&1)
    exit_code=$?
    
    stop_spinner
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "Virus database updated successfully"
        echo ""
        echo -e "  ${GRAY}$(get_db_info)${NC}"
        echo ""
        write_log "Database updated successfully"
        return 0
    else
        # Check if it's just "already up to date"
        if echo "$output" | grep -q "up to date"; then
            log_success "Virus database is already up to date"
            echo ""
            echo -e "  ${GRAY}$(get_db_info)${NC}"
            echo ""
            return 0
        else
            log_error "Failed to update database"
            echo ""
            echo -e "  ${GRAY}Error: $output${NC}"
            echo ""
            write_log "Database update failed: $output"
            return 1
        fi
    fi
}

# =============================================================================
# Scanning Functions
# =============================================================================

# Scan a single file
# Usage: scan_file "/path/to/file"
# Returns: 0 = clean, 1 = infected, 2 = error
scan_file() {
    local filepath="$1"
    
    if [[ ! -e "$filepath" ]]; then
        return 2
    fi
    
    local output
    output=$(clamscan --no-summary "$filepath" 2>&1)
    local exit_code=$?
    
    # ClamAV exit codes:
    # 0 = No virus found
    # 1 = Virus(es) found
    # 2 = Some error occurred
    
    case $exit_code in
        0) return 0 ;;  # Clean
        1) return 1 ;;  # Infected
        *) return 2 ;;  # Error
    esac
}

# Scan a directory with progress
# Usage: scan_directory "/path/to/dir" [verbose]
scan_directory() {
    local scan_path="$1"
    local verbose="${2:-0}"
    local recursive="${3:-1}"
    
    # Show banner first for consistent UI
    print_banner
    
    # Validate path
    if [[ ! -e "$scan_path" ]]; then
        echo ""
        log_error "Path does not exist: $scan_path"
        return 1
    fi
    
    # Check ClamAV status
    echo ""
    if ! check_clamav_status; then
        return 1
    fi
    
    # Warn if database is outdated
    show_db_age_warning
    
    local start_time
    start_time=$(date +%s)
    local infected_files=()
    local threats_count=0
    local files_count=0
    
    echo -e "  ${BOLD}Scanning:${NC} ${scan_path}"
    
    hide_cursor
    
    # Build clamscan options as array (prevents word splitting issues)
    local -a clam_opts=("--no-summary")
    [[ $recursive -eq 1 ]] && clam_opts+=("-r")
    
    # Add whitelist exclusions (Bash 3.2 compatible)
    local -a exclusions=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && exclusions+=("$line")
    done < <(build_exclusion_args)
    if [[ ${#exclusions[@]} -gt 0 ]]; then
        clam_opts+=("${exclusions[@]}")
    fi
    
    # Count total files for progress
    local total_files
    if [[ -d "$scan_path" ]]; then
        if [[ $recursive -eq 1 ]]; then
            total_files=$(find "$scan_path" -type f 2>/dev/null | wc -l | tr -d ' ')
        else
            total_files=$(find "$scan_path" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
        fi
    else
        total_files=1
    fi
    
    if [[ $total_files -eq 0 ]]; then
        log_warning "No files to scan in: $scan_path"
        show_cursor
        return 0
    fi
    
    echo -e "  ${GRAY}(${total_files} files)${NC}"
    # Print 2 empty lines for progress area
    echo ""
    echo ""
    
    # Spinner characters
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local max_display=50
    
    # Process clamscan output in real-time
    while IFS= read -r line; do
        if [[ "$line" =~ ^(.+):\ (.+)$ ]]; then
            local file_path="${BASH_REMATCH[1]}"
            local status="${BASH_REMATCH[2]}"
            ((files_count++))
            
            # Get spinner char
            local spin_char="${spin_chars:files_count%${#spin_chars}:1}"
            
            # Show current file being scanned
            local display_file="${file_path##*/}"
            if [[ ${#display_file} -gt $max_display ]]; then
                display_file="${display_file:0:$max_display}..."
            fi
            
            # Move up 2 lines, print spinner line with clear
            printf "\033[2A\033[K"
            printf "     ${CYAN}%s${NC} Scanning... ${GRAY}[%d/%d]${NC}\n" "$spin_char" "$files_count" "$total_files"
            # Print file line with clear
            printf "\033[K     ${GRAY}%s${NC}\n" "$display_file"
            
            # Check if infected
            if [[ "$status" == *"FOUND" ]]; then
                local virus_name="${status% FOUND}"
                infected_files+=("$file_path|$virus_name")
                ((threats_count++))
            fi
        fi
    done < <(clamscan "${clam_opts[@]}" "$scan_path" 2>&1)
    
    # Clear the 2 progress lines
    printf "\033[2A\033[K"
    if [[ $threats_count -gt 0 ]]; then
        printf "     ${RED}✗ ${threats_count} threat(s) found${NC}\n"
    else
        printf "     ${GREEN}✓ Clean${NC} ${GRAY}(${files_count} scanned)${NC}\n"
    fi
    printf "\033[K\n"
    
    show_cursor
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Show infected files if any
    if [[ ${#infected_files[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}${BOLD}Threats Found:${NC}"
        echo ""
        for item in "${infected_files[@]}"; do
            local file="${item%%|*}"
            local virus="${item##*|}"
            echo -e "  ${RED}${ICON_ERROR}${NC} ${virus}"
            echo -e "     ${GRAY}${file}${NC}"
        done
    fi
    
    # Show summary
    show_scan_summary "$files_count" "$threats_count" "$duration"
    
    # Save scan info
    save_last_scan "$scan_path" "$files_count" "$threats_count" "$duration"
    write_log "Scan completed: $scan_path - Files: $files_count, Threats: $threats_count"
    
    # Return based on threats found
    [[ $_SCAN_THREATS_COUNT -eq 0 ]] && return 0 || return 1
}

# Quick scan - scan common threat locations
quick_scan() {
    local verbose="${1:-0}"
    
    print_banner
    echo ""
    echo -e "  ${BOLD}Quick Scan${NC} - Scanning common threat locations"
    echo ""
    
    if ! check_clamav_status; then
        return 1
    fi
    
    # Warn if database is outdated
    show_db_age_warning
    
    local total_threats=0
    local total_files=0
    local scanned_files=0
    local start_time
    start_time=$(date +%s)
    local infected_files=()
    
    # Build exclusion args for quick scan too (Bash 3.2 compatible)
    local -a exclusions=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && exclusions+=("$line")
    done < <(build_exclusion_args)
    
    hide_cursor
    
    for path in "${DEFAULT_SCAN_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            # Count files in directory
            local file_count
            file_count=$(find "$path" -type f 2>/dev/null | wc -l | tr -d ' ')
            
            # Show what we're scanning
            echo -e "  ${CYAN}${ICON_FOLDER}${NC} ${path} ${GRAY}(${file_count} files)${NC}"
            # Print 2 empty lines for progress area
            echo ""
            echo ""
            
            # Scan directory with whitelist exclusions
            local -a quick_opts=("--no-summary" "-r")
            if [[ ${#exclusions[@]} -gt 0 ]]; then
                quick_opts+=("${exclusions[@]}")
            fi
            
            # Parse output while showing progress
            local path_threats=0
            local files_in_path=0
            local max_display=50  # Max chars to show for filename
            local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            
            # Process clamscan output in real-time
            # Format: /path/to/file: OK or /path/to/file: VirusName FOUND
            while IFS= read -r line; do
                if [[ "$line" =~ ^(.+):\ (.+)$ ]]; then
                    local file_path="${BASH_REMATCH[1]}"
                    local status="${BASH_REMATCH[2]}"
                    ((files_in_path++))
                    
                    # Get spinner char
                    local spin_char="${spin_chars:files_in_path%${#spin_chars}:1}"
                    
                    # Show current file being scanned
                    local display_file="${file_path##*/}"
                    if [[ ${#display_file} -gt $max_display ]]; then
                        display_file="${display_file:0:$max_display}..."
                    fi
                    
                    # Move up 2 lines, print spinner line with clear
                    printf "\033[2A\033[K"
                    printf "     ${CYAN}%s${NC} Scanning... ${GRAY}[%d/%d]${NC}\n" "$spin_char" "$files_in_path" "$file_count"
                    # Print file line with clear
                    printf "\033[K     ${GRAY}%s${NC}\n" "$display_file"
                    
                    # Check if infected
                    if [[ "$status" == *"FOUND" ]]; then
                        local virus_name="${status% FOUND}"
                        infected_files+=("$file_path|$virus_name")
                        ((total_threats++))
                        ((path_threats++))
                    fi
                fi
            done < <(clamscan "${quick_opts[@]}" "$path" 2>&1)
            
            scanned_files=$((scanned_files + files_in_path))
            total_files=$((total_files + file_count))
            
            # Clear the 2 progress lines and show result
            printf "\033[2A\033[K"
            if [[ $path_threats -gt 0 ]]; then
                printf "     ${RED}✗ ${path_threats} threat(s) found${NC}\n"
            else
                printf "     ${GREEN}✓ Clean${NC} ${GRAY}(${files_in_path} scanned)${NC}\n"
            fi
            printf "\033[K\n"
            printf "\r                                                                              \n"
        fi
    done
    
    show_cursor
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Show infected files if any
    if [[ ${#infected_files[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}${BOLD}Threats Found:${NC}"
        echo ""
        for item in "${infected_files[@]}"; do
            local file="${item%%|*}"
            local virus="${item##*|}"
            echo -e "  ${RED}${ICON_ERROR}${NC} ${virus}"
            echo -e "     ${GRAY}${file}${NC}"
        done
    fi
    
    # Use scanned_files for more accurate count
    show_scan_summary "$scanned_files" "$total_threats" "$duration"
    save_last_scan "Quick Scan" "$scanned_files" "$total_threats" "$duration"
    
    # Export to JSON if requested
    if [[ -n "${EXPORT_JSON:-}" ]]; then
        export_scan_results "Quick Scan" "$scanned_files" "$total_threats" "$duration" "${infected_files[@]}"
    fi
    
    return 0
}

# Full system scan
full_scan() {
    local verbose="${1:-0}"
    
    print_banner
    echo ""
    echo -e "  ${BOLD}${ICON_THREAT} Full System Scan${NC}"
    echo -e "  ${GRAY}This may take a while...${NC}"
    echo ""
    
    if ! check_clamav_status; then
        return 1
    fi
    
    # Warn if database is outdated
    show_db_age_warning
    
    local total_threats=0
    local total_files=0
    local scanned_files=0
    local start_time
    start_time=$(date +%s)
    local infected_files=()
    
    # Build exclusion args for full scan (Bash 3.2 compatible)
    local -a exclusions=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && exclusions+=("$line")
    done < <(build_exclusion_args)
    local -a full_opts=("--no-summary" "-r")
    if [[ ${#exclusions[@]} -gt 0 ]]; then
        full_opts+=("${exclusions[@]}")
    fi
    
    hide_cursor
    
    for path in "${FULL_SCAN_PATHS[@]}"; do
        if [[ -d "$path" ]]; then
            # Count files in directory
            local file_count
            file_count=$(find "$path" -type f 2>/dev/null | wc -l | tr -d ' ')
            
            # Show what we're scanning
            echo -e "  ${CYAN}${ICON_FOLDER}${NC} ${path} ${GRAY}(${file_count} files)${NC}"
            # Print 2 empty lines for progress area
            echo ""
            echo ""
            
            # Parse output while showing progress
            local path_threats=0
            local files_in_path=0
            local max_display=50
            local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            
            # Process clamscan output in real-time
            while IFS= read -r line; do
                if [[ "$line" =~ ^(.+):\ (.+)$ ]]; then
                    local file_path="${BASH_REMATCH[1]}"
                    local status="${BASH_REMATCH[2]}"
                    ((files_in_path++))
                    
                    # Get spinner char
                    local spin_char="${spin_chars:files_in_path%${#spin_chars}:1}"
                    
                    # Show current file being scanned
                    local display_file="${file_path##*/}"
                    if [[ ${#display_file} -gt $max_display ]]; then
                        display_file="${display_file:0:$max_display}..."
                    fi
                    
                    # Move up 2 lines, print spinner line with clear
                    printf "\033[2A\033[K"
                    printf "     ${CYAN}%s${NC} Scanning... ${GRAY}[%d/%d]${NC}\n" "$spin_char" "$files_in_path" "$file_count"
                    # Print file line with clear
                    printf "\033[K     ${GRAY}%s${NC}\n" "$display_file"
                    
                    # Check if infected
                    if [[ "$status" == *"FOUND" ]]; then
                        local virus_name="${status% FOUND}"
                        infected_files+=("$file_path|$virus_name")
                        ((total_threats++))
                        ((path_threats++))
                    fi
                fi
            done < <(clamscan "${full_opts[@]}" "$path" 2>&1)
            
            scanned_files=$((scanned_files + files_in_path))
            total_files=$((total_files + file_count))
            
            # Clear the 2 progress lines and show result
            printf "\033[2A\033[K"
            if [[ $path_threats -gt 0 ]]; then
                printf "     ${RED}✗ ${path_threats} threat(s) found${NC}\n"
            else
                printf "     ${GREEN}✓ Clean${NC} ${GRAY}(${files_in_path} scanned)${NC}\n"
            fi
            printf "\033[K\n"
        fi
    done
    
    show_cursor
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Show infected files if any
    if [[ ${#infected_files[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}${BOLD}All Threats Found:${NC}"
        echo ""
        for item in "${infected_files[@]}"; do
            local file="${item%%|*}"
            local virus="${item##*|}"
            echo -e "  ${RED}${ICON_ERROR}${NC} ${virus}"
            echo -e "     ${GRAY}${file}${NC}"
        done
    fi
    
    show_scan_summary "$scanned_files" "$total_threats" "$duration"
    save_last_scan "Full Scan" "$scanned_files" "$total_threats" "$duration"
    
    # Export to JSON if requested
    if [[ -n "${EXPORT_JSON:-}" ]]; then
        export_scan_results "Full Scan" "$scanned_files" "$total_threats" "$duration" "${infected_files[@]}"
    fi
    
    return 0
}

# =============================================================================
# Export Functions
# =============================================================================

# Export scan results to JSON
export_scan_results() {
    local scan_type="$1"
    local files_scanned="$2"
    local threats_found="$3"
    local duration="$4"
    shift 4
    local infected_files=("$@")
    
    local output_file="${EXPORT_JSON:-}"
    [[ -z "$output_file" ]] && return 0
    
    # Build JSON
    cat > "$output_file" << EOF
{
  "scan_type": "$scan_type",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "system": {
    "hostname": "$(hostname)",
    "os": "$(sw_vers -productName 2>/dev/null || echo 'macOS') $(sw_vers -productVersion 2>/dev/null || echo '')",
    "clamav_version": "$(get_clamav_version)"
  },
  "results": {
    "files_scanned": $files_scanned,
    "threats_found": $threats_found,
    "duration_seconds": $duration,
    "status": "$([ "$threats_found" -eq 0 ] && echo 'clean' || echo 'infected')"
  },
  "threats": [
EOF
    
    # Add threats array
    local first=1
    for item in "${infected_files[@]}"; do
        [[ -z "$item" ]] && continue
        local file="${item%%|*}"
        local virus="${item##*|}"
        
        [[ $first -eq 0 ]] && echo "," >> "$output_file"
        first=0
        
        cat >> "$output_file" << EOF
    {
      "file": "$file",
      "threat_name": "$virus",
      "quarantined": false
    }
EOF
    done
    
    # Close JSON
    cat >> "$output_file" << EOF
  ]
}
EOF
    
    log_success "Results exported to: $output_file"
}
