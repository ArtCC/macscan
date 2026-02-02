<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
  <img src="https://img.shields.io/badge/Version-0.0.1-orange?style=flat-square" alt="Version">
  <img src="https://img.shields.io/badge/Shell-Bash-lightgrey?style=flat-square" alt="Shell">
  <img src="https://img.shields.io/github/actions/workflow/status/your-username/macscan/ci.yml?style=flat-square&label=CI" alt="CI">
</p>

# 🛡️ MacScan

**Command-line malware scanner for macOS** — Simple, fast, and transparent.

MacScan is an open-source CLI tool designed to scan your Mac for malware, adware, and potentially unwanted software. Built for power users and security researchers who prefer the terminal over bloated GUI applications.

## ✨ Features

- **Quick Scan** — Scan common threat locations in seconds
- **Full System Scan** — Deep scan of your entire system
- **Path Scan** — Scan specific directories
- **Quarantine** — Isolate and manage infected files
- **Whitelist** — Exclude trusted paths from scans
- **Auto-updates** — Keep virus signatures up to date
- **JSON Export** — Export scan results for automation
- **macOS Notifications** — Native alerts on scan completion
- **Beautiful TUI** — Colors, progress bars, and spinners
- **Lightweight** — Pure Bash with ClamAV backend
- **Transparent** — Open source, no telemetry, no hidden behavior

## 📦 Installation

### Prerequisites

MacScan requires [ClamAV](https://www.clamav.net/) as its scanning engine:

```bash
brew install clamav
```

### Install MacScan

```bash
# Clone the repository
git clone https://github.com/your-username/macscan.git
cd macscan

# Run the installer
./install.sh
```

### Post-installation

Initialize the virus database (required before first scan):

```bash
ms update
```

## 🚀 Quick Start

```bash
# Quick scan (common threat locations)
ms scan

# Scan a specific directory
ms scan --path ~/Downloads

# Full system scan
ms scan --full

# Preview what will be scanned
ms scan --dry-run

# Silent scan with notification
ms scan --quiet --notify

# Export results to JSON
ms scan --export results.json

# Update virus signatures
ms update

# Show status and last scan info
ms status

# Manage quarantined files
ms quarantine list

# Show help
ms help
```

## 📖 Commands

| Command | Description |
|---------|-------------|
| `ms scan` | Quick scan of common threat locations |
| `ms scan --path <dir>` | Scan a specific directory |
| `ms scan --full` | Full system scan (takes longer) |
| `ms update` | Update ClamAV virus database |
| `ms status` | Show system status and last scan info |
| `ms quarantine` | Manage quarantined files |
| `ms remove` | Uninstall MacScan |
| `ms help` | Show help information |
| `ms version` | Show version information |

### Options

| Option | Description |
|--------|-------------|
| `-p, --path <dir>` | Specify directory to scan |
| `-f, --full` | Perform full system scan |
| `-v, --verbose` | Show detailed output |
| `-q, --quiet` | Suppress output (for scripts) |
| `--dry-run` | Show what would be scanned without scanning |
| `--no-color` | Disable colored output |
| `--notify` | Send macOS notification on completion |
| `--export <file>` | Export results to JSON file |
| `-h, --help` | Show help for a command |

## 📁 Directory Structure

MacScan follows the [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html):

```
/usr/local/bin/
├── macscan                 # Main command
└── ms                      # Short alias

~/.config/macscan/          # Configuration
├── config.conf             # User settings
├── whitelist               # Scan exclusions
├── bin/                    # Installed scripts
└── lib/                    # Library modules

~/.local/share/macscan/     # Persistent data
├── quarantine/             # Isolated threats
└── logs/                   # Scan history

~/.cache/macscan/           # Temporary cache
└── last_scan               # Last scan info
```

## 🔧 Configuration

Configuration file: `~/.config/macscan/config.conf`

```ini
# Example configuration
verbose=0
auto_update=1
```

### Whitelist

Exclude paths from scanning by adding them to `~/.config/macscan/whitelist`:

```
/path/to/exclude
/another/path
```

## 🧪 Development

### Project Structure

```
macscan/
├── bin/
│   ├── macscan             # Main entry point
│   └── ms                  # Alias script
├── lib/
│   ├── core/
│   │   ├── common.sh       # Utilities and helpers
│   │   └── colors.sh       # ANSI colors and formatting
│   ├── scan/
│   │   └── clamav.sh       # ClamAV wrapper
│   └── ui/
│       ├── spinner.sh      # Loading spinners
│       └── progress.sh     # Progress bars
├── completions/
│   ├── macscan.bash        # Bash completion
│   └── _macscan            # Zsh completion
├── docs/
│   └── TROUBLESHOOTING.md  # Common issues
├── .github/
│   └── workflows/ci.yml    # GitHub Actions
├── install.sh              # Installer
├── uninstall.sh            # Uninstaller
├── LICENSE                 # MIT License
└── README.md               # This file
```

### Running from Source

```bash
# Clone and enter directory
git clone https://github.com/your-username/macscan.git
cd macscan

# Run directly without installing
./bin/ms scan
./bin/ms --help
```

## 🗑️ Uninstallation

```bash
# If installed
ms remove

# Or run the uninstaller directly
~/.config/macscan/uninstall.sh

# Or from the source directory
./uninstall.sh
```

This will remove:
- `/usr/local/bin/macscan` and `/usr/local/bin/ms`
- `~/.config/macscan/`
- `~/.local/share/macscan/`
- `~/.cache/macscan/`

> Note: ClamAV is not removed. To remove it: `brew uninstall clamav`

## 🛣️ Roadmap

### Phase 1 - MVP ✅
- [x] Basic CLI structure
- [x] ClamAV integration
- [x] Quick/Full/Path scanning
- [x] TUI with colors and progress
- [x] Installer/Uninstaller

### Phase 2 - Core Features ✅
- [x] Quarantine management
- [x] Whitelist support
- [x] JSON export
- [x] macOS notifications
- [x] Shell completions (Bash/Zsh)
- [x] GitHub Actions CI
- [ ] YARA rules integration
- [ ] macOS-specific malware hashes (Objective-See)
- [ ] Interactive TUI menu (with gum/fzf)
- [ ] Homebrew tap

### Phase 3 - Advanced
- [ ] Real-time monitoring (fswatch)
- [ ] Native macOS notifications
- [ ] Scheduled scans (launchd)
- [ ] Detailed reports
- [ ] Whitelist management UI

### Phase 4 - Community
- [ ] Community rule contributions
- [ ] VirusTotal API integration
- [ ] Plugin system

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ClamAV](https://www.clamav.net/) - Open source antivirus engine
- [Mole](https://github.com/tw93/Mole) - Inspiration for TUI design
- [Objective-See](https://objective-see.org/) - macOS security research

## ⚠️ Disclaimer

MacScan is provided as-is without warranty. While it uses ClamAV's virus database, no antivirus solution is 100% effective. Always practice safe computing habits and keep your system updated.

---

<p align="center">
  Made with ❤️ for the macOS community
</p>
