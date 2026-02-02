# Contributing to MacScan

First off, thank you for considering contributing to MacScan! 🎉

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Pull Requests](#pull-requests)
- [Development Setup](#development-setup)
- [Coding Guidelines](#coding-guidelines)
- [Testing](#testing)
- [Commit Messages](#commit-messages)

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check existing issues to avoid duplicates.

**When reporting a bug, include:**
- macOS version (`sw_vers`)
- Bash version (`bash --version`)
- ClamAV version (`clamscan --version`)
- Steps to reproduce
- Expected vs actual behavior
- Any error messages

**Use this template:**
```markdown
**Environment:**
- macOS: 
- Bash: 
- ClamAV: 
- MacScan: 

**Steps to reproduce:**
1. 
2. 
3. 

**Expected behavior:**

**Actual behavior:**

**Error output (if any):**
```

### Suggesting Features

Feature suggestions are welcome! Please:
- Check if the feature is already in the [Roadmap](README.md#-roadmap)
- Describe the problem you're trying to solve
- Explain your proposed solution
- Consider backward compatibility

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run ShellCheck (`shellcheck -x bin/macscan`)
5. Test your changes manually
6. Commit with a descriptive message
7. Push to your fork
8. Open a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/macscan.git
cd macscan

# Make scripts executable
chmod +x bin/macscan bin/ms install.sh uninstall.sh

# Run from source (no installation needed)
./bin/ms --version
./bin/ms help

# Install ShellCheck for linting
brew install shellcheck

# Run linting
shellcheck -x bin/macscan bin/ms
find lib -name "*.sh" -exec shellcheck -x {} \;
```

## Coding Guidelines

### Bash Best Practices

```bash
# Always use strict mode
set -euo pipefail

# Quote variables
echo "$variable"  # ✓
echo $variable    # ✗

# Use arrays for command options
local -a opts=("--flag1" "--flag2")
command "${opts[@]}"

# Use [[ ]] instead of [ ]
[[ -f "$file" ]]  # ✓
[ -f "$file" ]    # ✗

# Use $(command) instead of backticks
result=$(command)  # ✓
result=`command`   # ✗

# Document functions
# Description of what function does
# Usage: function_name "arg1" "arg2"
# Returns: 0 on success, 1 on error
function_name() {
    local arg1="$1"
    # ...
}
```

### Project Structure

```
macscan/
├── bin/           # Executable scripts
├── lib/           # Library modules
│   ├── core/      # Core utilities
│   ├── scan/      # Scanning logic
│   └── ui/        # UI components
├── completions/   # Shell completions
├── .github/       # GitHub configs
└── docs/          # Documentation
```

### Module Guidelines

- Prevent multiple sourcing with `[[ -n "${_MODULE_LOADED:-}" ]] && return 0`
- Use `readonly` for constants
- Keep functions focused and single-purpose
- Handle errors gracefully

## Testing

Currently, MacScan doesn't have automated tests. Manual testing checklist:

```bash
# Basic functionality
./bin/ms --version
./bin/ms help
./bin/ms status

# Scanning (requires ClamAV)
./bin/ms scan --dry-run
./bin/ms scan --path ~/Downloads --dry-run

# Options
./bin/ms scan --quiet --dry-run
./bin/ms scan --no-color --dry-run
./bin/ms scan --export test.json --dry-run

# Quarantine
./bin/ms quarantine list
./bin/ms quarantine help
```

## Commit Messages

Follow conventional commits:

```
type(scope): description

[optional body]

[optional footer]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting (no code change)
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

**Examples:**
```
feat(scan): add --dry-run option
fix(spinner): handle SIGINT properly
docs(readme): update installation instructions
refactor(clamav): use arrays for command options
```

---

Thank you for contributing! 🛡️
