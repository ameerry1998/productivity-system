# Productivity System

A comprehensive macOS productivity system that blocks browsers and distracting apps based on location and time limits.

## Recent Updates (October 13, 2025)

### New Feature: 4-Hour Home Usage Limiter 🔒

**Added:** `home_usage_limiter.sh` - Tracks cumulative laptop usage at home and locks the screen after 4 hours.

**Features:**
- **Cumulative tracking**: Tracks total time at home throughout the day, even if you leave and return
- **Hard screen lock**: Uses `CGSession -suspend` requiring password to unlock (not the instant-unlock type)
- **Smart notifications**: Warns at 2h, 1h, 30m, and 10m remaining
- **No exceptions**: Enforces the limit strictly
- **Unified logging**: All logs use `[SCRIPT_NAME]` format for easy debugging

### Fixed: Reliable Home Network Detection

**Problem:** The previous version used gateway MAC addresses for home detection, but MAC addresses change frequently, causing the script to fail to detect home networks.

**Solution:** Switched to using **unredacted SSID scanning** via Swift/CoreWLAN, which is reliable and doesn't break when network hardware changes.

### Key Changes in `screen_lock.sh`

1. **Removed**: Unreliable gateway MAC address detection
2. **Added**: `get_ssids_in_range()` function using Swift/CoreWLAN
3. **Simplified**: Detection logic now only checks for SSIDs in range
4. **Result**: Reliable, future-proof home network detection

```bash
# New detection method (lines 43-57)
get_ssids_in_range() {
    /usr/bin/swift - 2>/dev/null <<'SWIFT'
import Foundation
import CoreWLAN

let client = CWWiFiClient.shared()
guard let iface = client.interface() else { exit(1) }
do {
    let networks = try iface.scanForNetworks(withSSID: nil)
    let ssids = Set(networks.compactMap { $0.ssid }.filter { !$0.isEmpty })
    for s in ssids.sorted() { print(s) }
} catch { exit(2) }
SWIFT
}
```

## Components

### Scripts (`/usr/local/productivity/`)

- **`home_usage_limiter.sh`** - 🆕 Locks laptop after 4 hours cumulative use at home
- **`screen_lock.sh`** - Blocks browsers when at home (using SSID detection)
- **`browser_timer.sh`** - Enforces 4.5 hour daily limit with 45-minute sessions
- **`browser_control.sh`** - Additional browser control
- **`time_protection.sh`** - Prevents time manipulation
- **`block_apple_configurator.sh`** - Blocks system configuration tampering
- **`master_watchdog.sh`** - Protects all productivity scripts from being killed
- **`productivity-manager.sh`** - Central management interface
- **`productivity-logs.sh`** - 🆕 Unified log viewer for all productivity scripts
- **`learn_home_network.sh`** - Helper to add new home networks (legacy, no longer needed)
- **`geofence_monitor.sh`** - Location-based monitoring

### LaunchDaemons (`/Library/LaunchDaemons/`)

Each script has a corresponding `.plist` file that runs it as a system daemon:

- `com.productivity.lock.plist` - Runs `screen_lock.sh`
- `com.productivity.timer.plist` - Runs `browser_timer.sh`
- `com.productivity.browser.plist` - Runs `browser_control.sh`
- `com.productivity.time-protection.plist` - Runs `time_protection.sh`
- `com.productivity.configurator-blocker.plist` - Runs `block_apple_configurator.sh`
- `com.productivity.master-watchdog.plist` - Runs `master_watchdog.sh`

## Configuration

### Home Networks

Edit `screen_lock.sh` to add your home network SSIDs:

```bash
HOME_NETWORKS=(
    "GL-AXT1800-13d"
    "GL-AXT1800-13d-5G" 
    "Shawarma_signals"
)
```

### Time Limits

Edit `browser_timer.sh` to change time limits:

```bash
DAILY_LIMIT=16200  # 4.5 hours in seconds
HOURLY_LIMIT=2700  # 45 minutes in seconds
BREAK_DURATION=1500  # 25 minutes in seconds
```

## Installation

1. Copy scripts to `/usr/local/productivity/`
2. Copy plist files to `/Library/LaunchDaemons/`
3. Load the LaunchDaemons:

```bash
sudo launchctl load /Library/LaunchDaemons/com.productivity.*.plist
```

## Management

### Productivity Manager

Use the `productivity-manager.sh` script:

```bash
# Check status
productivity-manager status

# Start all services
productivity-manager start all

# Stop a specific service (requires sudo)
sudo productivity-manager stop lock

# View logs
sudo productivity-manager logs lock

# Live monitoring
sudo productivity-manager live
```

### Unified Log Viewer 🆕

Use `productivity-logs` to view all logs in one place:

```bash
# View statistics and current usage
productivity-logs stats

# Stream all logs in real-time
productivity-logs live

# Show last 100 log entries
productivity-logs tail 100

# Show today's logs
productivity-logs today

# Search for specific term
productivity-logs search "home network"
```

## How It Works

### Home Detection (screen_lock.sh)

1. **USB Tethering Check** (highest priority): If iPhone USB or USB Ethernet is active, assume at home
2. **SSID Scanning**: Scan for all WiFi networks in range using Swift/CoreWLAN
3. **Match**: If any home network SSID is detected, block browsers

### Browser Blocking

When at home, the script kills browsers every 3 seconds:
- Arc
- Safari
- Chrome
- Firefox
- Edge
- Opera
- Brave
- And more...

### Time Limits (browser_timer.sh)

- Tracks total browser usage daily
- Enforces 45-minute sessions
- Requires 25-minute breaks between sessions
- Blocks browsers from 5:00 AM to 10:40 AM

### Watchdog Protection

The `master_watchdog.sh` ensures all scripts keep running:
- Restarts scripts if they're killed
- Monitors LaunchDaemons
- Cannot be easily bypassed without sudo + YubiKey

## YubiKey Authentication

Sudo access requires YubiKey authentication, stored in `/etc/Yubico/u2f_keys`. This prevents easy bypass of the productivity system.

## Troubleshooting

### Browsers not getting blocked at home?

1. Check if the script is running:
   ```bash
   ps aux | grep screen_lock.sh
   ```

2. Check the logs:
   ```bash
   tail -f /var/log/screen_lock.log
   ```

3. Test SSID detection manually:
   ```bash
   /Users/arayan/Desktop/scan-ssids.sh
   ```

4. Verify your home network names are in the `HOME_NETWORKS` array

### Scripts not restarting automatically?

Check if the LaunchDaemon is loaded:
```bash
sudo launchctl list | grep productivity
```

If not loaded:
```bash
sudo launchctl load /Library/LaunchDaemons/com.productivity.lock.plist
```

## Version Control

This repository tracks all changes to the productivity system. After making changes to live scripts:

```bash
# Copy latest versions to repo
cd ~/Desktop/productivity-system-repo
sudo cp /usr/local/productivity/*.sh scripts/
sudo cp /Library/LaunchDaemons/com.productivity.*.plist launch-daemons/
sudo chown -R arayan:staff .

# Commit and push
git add .
git commit -m "Description of changes"
git push
```

## License

Personal use only.


---

## 📚 **Complete Documentation**

- **[SCRIPTS_REFERENCE.md](SCRIPTS_REFERENCE.md)** - Complete inventory of all scripts, what they do, and when to use them
- **[YUBIKEY_SETUP.md](YUBIKEY_SETUP.md)** - YubiKey configuration and troubleshooting (register-yubikey script)
- **[FRESH_INSTALL_GUIDE.md](FRESH_INSTALL_GUIDE.md)** - How to install on a new Mac
- **[SESSION_LOG_2025-10-13.md](SESSION_LOG_2025-10-13.md)** - Debugging session history and fixes

---

## 🚀 **Quick Start (New Mac)**

```bash
# 1. Clone repo
git clone git@github.com:ameerry1998/productivity-system.git
cd productivity-system

# 2. Run installer
sudo bash INSTALL.sh

# 3. Configure home networks
sudo nano /usr/local/productivity/screen_lock.sh
# Edit HOME_NETWORKS array

# 4. Register YubiKey
register-yubikey

# 5. Done! Check status
productivity-manager status
```

---

## 📊 **System Status**

Check what's running:
```bash
productivity-manager status
```

View logs:
```bash
productivity-logs live
```

Reload after editing scripts:
```bash
productivity-reload
```

---

**Last Updated:** October 13, 2025  
**System Status:** ✅ Fully Operational
