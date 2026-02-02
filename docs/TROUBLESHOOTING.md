# Troubleshooting Guide

Common issues and their solutions for MacScan.

## Table of Contents

- [Installation Issues](#installation-issues)
- [ClamAV Issues](#clamav-issues)
- [Scanning Issues](#scanning-issues)
- [Performance Issues](#performance-issues)
- [Display Issues](#display-issues)

---

## Installation Issues

### "Cannot find MacScan libraries" error

**Problem:** When running `ms` or `macscan`, you see:
```
Error: Cannot find MacScan libraries
Please reinstall MacScan or run from the source directory
```

**Solutions:**

1. **If running from source**, make sure you're in the correct directory:
   ```bash
   cd /path/to/macscan
   ./bin/ms --version
   ```

2. **If installed**, reinstall MacScan:
   ```bash
   cd /path/to/macscan
   ./install.sh
   ```

3. **Check installation paths:**
   ```bash
   ls -la ~/.config/macscan/lib/
   ls -la /usr/local/bin/macscan
   ```

### Permission denied during installation

**Problem:** Installation fails with permission errors.

**Solution:** The installer will prompt for sudo if needed. If it fails:
```bash
# Check write permissions
ls -la /usr/local/bin/

# Manually install with sudo
sudo ./install.sh
```

### Command not found after installation

**Problem:** `ms` command not recognized after installation.

**Solutions:**

1. **Restart your terminal** or run:
   ```bash
   source ~/.bashrc  # or ~/.zshrc
   ```

2. **Check PATH:**
   ```bash
   echo $PATH | grep -o '/usr/local/bin'
   ```

3. **Add to PATH if missing:**
   ```bash
   echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

---

## ClamAV Issues

### "ClamAV is not installed" error

**Problem:** MacScan can't find ClamAV.

**Solution:**
```bash
# Install ClamAV via Homebrew
brew install clamav

# Verify installation
which clamscan
clamscan --version
```

### "Virus database not initialized" warning

**Problem:** ClamAV database is empty.

**Solution:**
```bash
# Update the virus database
ms update

# If that fails, try manually:
sudo freshclam
```

### freshclam fails with permission errors

**Problem:** Can't update virus database.

**Solutions:**

1. **Check database directory:**
   ```bash
   ls -la /opt/homebrew/var/lib/clamav/
   ```

2. **Fix permissions:**
   ```bash
   sudo chown -R $(whoami) /opt/homebrew/var/lib/clamav/
   ```

3. **Create config if missing:**
   ```bash
   # Copy sample config
   cp /opt/homebrew/etc/clamav/freshclam.conf.sample /opt/homebrew/etc/clamav/freshclam.conf
   
   # Edit and comment out "Example" line
   sed -i '' 's/^Example/#Example/' /opt/homebrew/etc/clamav/freshclam.conf
   ```

### "Database is older than 7 days" warning

**Problem:** Virus signatures are outdated.

**Solution:**
```bash
ms update
```

---

## Scanning Issues

### Scan hangs or takes forever

**Problem:** Scan seems stuck.

**Solutions:**

1. **Use quick scan instead of full scan:**
   ```bash
   ms scan  # Quick scan
   # instead of
   ms scan --full
   ```

2. **Scan specific directory:**
   ```bash
   ms scan --path ~/Downloads
   ```

3. **Check what would be scanned:**
   ```bash
   ms scan --dry-run
   ```

4. **Add large directories to whitelist:**
   ```bash
   echo "/path/to/large/directory" >> ~/.config/macscan/whitelist
   ```

### "Path does not exist" error

**Problem:** Specified path not found.

**Solutions:**

1. **Use absolute path:**
   ```bash
   ms scan --path /Users/yourname/Downloads
   # instead of
   ms scan --path ~/Downloads  # Should work, but try absolute if issues
   ```

2. **Check path exists:**
   ```bash
   ls -la "/path/to/directory"
   ```

### Scan not finding known threats

**Problem:** Expected threats not detected.

**Solutions:**

1. **Update virus database:**
   ```bash
   ms update
   ```

2. **Check file isn't in whitelist:**
   ```bash
   cat ~/.config/macscan/whitelist
   ```

3. **Run verbose scan:**
   ```bash
   ms scan --path /path/to/file --verbose
   ```

---

## Performance Issues

### Scan is very slow

**Solutions:**

1. **Use quick scan for daily checks:**
   ```bash
   ms scan  # Limited depth, faster
   ```

2. **Whitelist trusted directories:**
   ```bash
   # Add to ~/.config/macscan/whitelist
   /path/to/node_modules
   /path/to/virtual_environments
   /path/to/.git
   ```

3. **Scan during off-hours:**
   ```bash
   # Use quiet mode and notifications
   ms scan --full --quiet --notify
   ```

### High CPU usage during scan

**Problem:** System becomes unresponsive during scan.

**Solutions:**

1. ClamAV is CPU-intensive by design. Consider:
   - Running scans during idle time
   - Using quick scan instead of full scan
   - Excluding large directories

2. **Use nice to lower priority:**
   ```bash
   nice -n 10 ms scan --full
   ```

---

## Display Issues

### Colors not showing correctly

**Problem:** ANSI colors appear as codes or garbage.

**Solutions:**

1. **Disable colors:**
   ```bash
   ms scan --no-color
   ```

2. **Check terminal supports colors:**
   ```bash
   echo $TERM  # Should be xterm-256color or similar
   ```

3. **Set TERM variable:**
   ```bash
   export TERM=xterm-256color
   ```

### Progress bar looks broken

**Problem:** Progress bar characters appear wrong.

**Solutions:**

1. **Use a Unicode-compatible terminal** (iTerm2, Terminal.app, Alacritty)

2. **Check font supports Unicode:**
   - Use a Nerd Font or similar
   - SF Mono, Menlo, or Monaco should work

3. **Resize terminal** - narrow terminals may cause issues

### Spinner not animating

**Problem:** Loading spinner doesn't move.

**Cause:** Output is being piped or redirected.

**Solution:** This is expected behavior. When not in an interactive terminal, spinner is disabled.

---

## Getting Help

If your issue isn't covered here:

1. **Check existing issues:**
   https://github.com/your-username/macscan/issues

2. **Create a new issue** with:
   - macOS version
   - Bash version
   - ClamAV version
   - Steps to reproduce
   - Error messages

3. **Run with debug mode:**
   ```bash
   MACSCAN_DEBUG=1 ms scan
   ```
