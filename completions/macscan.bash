#!/bin/bash
# MacScan - Bash completion script
# Add to ~/.bashrc: source /path/to/macscan.bash

_macscan_completions() {
    local cur prev opts commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # Main commands
    commands="scan update status quarantine whitelist remove help version author"
    
    # Global options
    global_opts="--help --version"
    
    # Whitelist actions
    whitelist_actions="list add remove edit help"
    
    # Scan options
    scan_opts="-p --path -f --full -v --verbose -q --quiet --dry-run --no-color --notify --export -h --help"
    
    # Quarantine actions
    quarantine_actions="list restore delete clean help"
    
    # Complete based on position
    case "${COMP_WORDS[1]}" in
        scan)
            case "$prev" in
                -p|--path)
                    # Complete with directories
                    COMPREPLY=( $(compgen -d -- "$cur") )
                    return 0
                    ;;
                --export)
                    # Complete with JSON files
                    COMPREPLY=( $(compgen -f -X '!*.json' -- "$cur") )
                    return 0
                    ;;
                *)
                    COMPREPLY=( $(compgen -W "$scan_opts" -- "$cur") )
                    return 0
                    ;;
            esac
            ;;
        quarantine)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$quarantine_actions" -- "$cur") )
                return 0
            fi
            ;;
        whitelist)
            if [[ ${COMP_CWORD} -eq 2 ]]; then
                COMPREPLY=( $(compgen -W "$whitelist_actions" -- "$cur") )
                return 0
            elif [[ ${COMP_CWORD} -eq 3 ]] && [[ "$prev" == "add" || "$prev" == "remove" ]]; then
                COMPREPLY=( $(compgen -d -- "$cur") )
                return 0
            fi
            ;;
        update|status|remove|help|version|author)
            COMPREPLY=( $(compgen -W "--help" -- "$cur") )
            return 0
            ;;
        *)
            if [[ ${COMP_CWORD} -eq 1 ]]; then
                COMPREPLY=( $(compgen -W "$commands $global_opts" -- "$cur") )
                return 0
            fi
            ;;
    esac
}

# Register completions
complete -F _macscan_completions macscan
complete -F _macscan_completions ms
