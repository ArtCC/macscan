# Changelog

All notable changes to MacScan will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.2] - 2026-02-02

### Added
- **Interactive menu**: Run `ms` without arguments for a TUI menu with arrow navigation
- **Whitelist CLI**: New `ms whitelist` command with `list`, `add`, `remove`, `edit` subcommands
- **Author command**: `ms author` to show author information
- **ASCII art banner**: Beautiful header in help and interactive menu
- **Auto-install dependencies**: Installer now offers to install Homebrew and ClamAV if missing
- **Keyboard shortcuts**: H (help), V (version), A (author), Q (quit) in interactive menu

### Changed
- `ms` without arguments now shows interactive menu instead of help
- Improved installer with dependency detection and user prompts
- Better Bash 3.2 compatibility (replaced mapfile with while-read loops)
- Help command now shows ASCII art banner

### Fixed
- Signal handling: Ctrl+C now properly restores cursor visibility
- Installer checks for existing `ms` command to avoid conflicts

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

[Unreleased]: https://github.com/artcc/macscan/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/artcc/macscan/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/artcc/macscan/releases/tag/v0.0.1
