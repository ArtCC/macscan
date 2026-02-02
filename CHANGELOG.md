# Changelog

All notable changes to MacScan will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Quarantine management**: New `ms quarantine` command with `list`, `restore`, `delete`, and `clean` subcommands
- **Uninstall command**: `ms remove` to uninstall MacScan directly from CLI
- **Dry-run mode**: `--dry-run` flag to preview what would be scanned
- **Quiet mode**: `--quiet` flag for silent operation in scripts
- **No-color mode**: `--no-color` flag to disable ANSI colors
- **macOS notifications**: `--notify` flag to send native notifications on scan completion
- **JSON export**: `--export <file>` flag to export scan results to JSON
- **Whitelist support**: Paths in `~/.config/macscan/whitelist` are now excluded from scans
- **Database age warning**: Warns if virus database is more than 7 days old
- **Shell completions**: Bash and Zsh autocompletion scripts
- **GitHub Actions CI**: Automated linting with ShellCheck

### Changed
- Improved path validation with security checks
- Better progress bar that adapts to terminal width
- More accurate file counting in quick scan
- Spinner now handles interruption (Ctrl+C) cleanly
- `format_size` no longer depends on `bc` (uses `awk` instead)

### Fixed
- Fixed variable expansion issues with clamscan options (now uses arrays)
- Fixed progress bar display issues in narrow terminals
- Fixed spinner not stopping cleanly when interrupted
- Fixed file counter not incrementing correctly in pipe operations

## [0.0.1] - 2026-01-15

### Added
- Initial release
- Quick scan of common threat locations
- Full system scan
- Path-specific scanning
- ClamAV integration for virus detection
- Colorful TUI with progress bars and spinners
- XDG-compliant directory structure
- Install and uninstall scripts
- Status command showing system and scan info
- Virus database update command

---

[Unreleased]: https://github.com/your-username/macscan/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/your-username/macscan/releases/tag/v0.0.1
