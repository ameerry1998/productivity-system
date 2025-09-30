# Productivity System

A comprehensive macOS productivity blocking system with location-based browser control, time limits, and anti-tampering protection.

## Architecture

```
📱 Productivity Manager (Supreme Authority)
  └── 🛡️ Master Watchdog (Protector Level)
      └── ⚙️ Individual Scripts (Protected Level)
```

## Core Components

### Scripts (`/scripts/`)
- **`screen_lock.sh`** - Location-based browser blocking (home WiFi detection)
- **`browser_timer.sh`** - Time limits & tracking (4.5h daily, 45min sessions)
- **`browser_control.sh`** - Additional browser control (passive)
- **`block_apple_configurator.sh`** - Anti-tampering protection
- **`time_protection.sh`** - Time sync protection (anti-manipulation)
- **`master_watchdog.sh`** - Master watchdog protecting all scripts

### LaunchDaemons (`/launch-daemons/`)
- Auto-start services that keep scripts running as root
- Located at: `/Library/LaunchDaemons/com.productivity.*.plist`

### Management (`/manager/`)
- **`productivity-manager.sh`** - Central control script with watchdog override
- **`install-watchdog-system.sh`** - Installation script for watchdog architecture

## Usage

### Check System Status
```bash
sudo ./manager/productivity-manager.sh status
```

### Stop/Start Individual Services
```bash
# Stop specific services
sudo ./manager/productivity-manager.sh stop timer
sudo ./manager/productivity-manager.sh stop lock
sudo ./manager/productivity-manager.sh stop configurator

# Start specific services  
sudo ./manager/productivity-manager.sh start timer
sudo ./manager/productivity-manager.sh start lock

# Restart services
sudo ./manager/productivity-manager.sh restart browser
sudo ./manager/productivity-manager.sh restart all

# Stop all services
sudo ./manager/productivity-manager.sh stop all

# Start all services
sudo ./manager/productivity-manager.sh start all
```

### Available Service Names
- **`lock`** - Location-based browser blocking
- **`timer`** - Time limits & tracking  
- **`browser`** - Additional browser control
- **`configurator`** - Anti-tampering protection
- **`time`** - Time sync protection
- **`profile`** - Profile protection
- **`master-watchdog`** - Supreme watchdog protection

### Sync Latest Changes
```bash
# Run this before committing to capture current system state
sudo ./sync-from-system.sh
```

## Recent Changes (Oct 2025)

- USB tether blocking: `screen_lock.sh` now blocks when iPhone USB/USB Ethernet is the default route (even if Wi‑Fi is still associated). Toggle via `TETHER_BLOCK=1` in the script. Logs to `/var/log/screen_lock.log`.
- Morning block window changed to 05:00–10:40 (was 05:00–12:00) in `browser_timer.sh`.
- Start without sudo: The manager can request starts via the watchdog. Disables/stops still require sudo.

## Start Without sudo (Watchdog Assist)

You can ask the watchdog to re‑enable services without sudo:

```bash
# Start all services via watchdog (no sudo)
productivity-manager start all

# Start a single service (e.g., lock) via watchdog (no sudo)
productivity-manager start lock
```

Behind the scenes the manager writes an override command that the master watchdog consumes and then brings services back online.

## What Still Requires sudo (and YubiKey)

- `productivity-manager stop <service>` / `stop all`
- `productivity-manager restart <service>` / `restart all`
- launchctl operations (bootout/bootstrap/kickstart)
- reading protected logs in `/var/log` (sometimes)
- installing/updating the hardened manager in `/usr/local/productivity`

## Hardened Manager (root‑owned, still runnable without sudo)

Install/update the root‑owned manager and convenience symlink:

```bash
sudo mkdir -p /usr/local/productivity
sudo cp manager/productivity-manager.sh /usr/local/productivity/productivity-manager.sh
sudo chown root:wheel /usr/local/productivity/productivity-manager.sh
sudo chmod 755 /usr/local/productivity/productivity-manager.sh
sudo ln -sf /usr/local/productivity/productivity-manager.sh /usr/local/bin/productivity-manager

# Optional: make immutable (clear with nouchg before updating)
# sudo chflags uchg /usr/local/productivity/productivity-manager.sh
```

## USB Tether Test Steps

```bash
networksetup -setairportpower en0 off               # turn Wi‑Fi off
route -n get default | awk '/interface|gateway/ {print}'
tail -f /var/log/screen_lock.log                    # look for USB tether messages
```

If your USB service label differs, edit `services=(...)` inside `scripts/screen_lock.sh` and reload the `lock` daemon.

## How Watchdogs Work

### 3-Level Protection Architecture
```
📱 Productivity Manager (Level 1: Supreme Authority)
    ├── Can override any watchdog protection
    ├── Sends commands via: /tmp/productivity-manager-overrides/
    └── Only authority that can truly disable services

🛡️ Master Watchdog (Level 2: Protector)  
    ├── Monitors all productivity services every 15 seconds
    ├── Respects manager override commands
    ├── Auto-restarts killed services within 15 seconds
    ├── Restores corrupted plist files from backup
    └── Cannot be easily killed (KeepAlive + self-protection)

⚙️ Individual Scripts (Level 3: Protected)
    ├── Run as LaunchDaemons (auto-start on boot)
    ├── Protected by master watchdog
    └── Will restart automatically if killed
```

### Watchdog Communication System
When you stop a service via the manager:
1. **Manager** sends "disable" command to `/tmp/productivity-manager-overrides/command-servicename`
2. **Master Watchdog** reads command and creates "disabled-servicename" flag
3. **Manager** then safely stops the service 
4. **Watchdog** sees the disable flag and ignores the stopped service
5. Service stays stopped until manager sends "enable" command

### Protection Against Tampering
- **Someone kills a script** → Watchdog restarts it within 15 seconds
- **Someone deletes plist file** → Watchdog restores from backup
- **Someone kills the watchdog** → launchd restarts it (KeepAlive: true)
- **Someone tries `launchctl unload`** → Watchdog re-enables the service
- **Only the manager can override** → Via the command system

### Check Watchdog Status
```bash
# View real-time watchdog activity
tail -f /var/log/productivity_watchdog.log

# Check if watchdog is running
sudo ./manager/productivity-manager.sh status | grep master-watchdog

# Manual watchdog restart (if needed)
sudo launchctl bootout system /Library/LaunchDaemons/com.productivity.master-watchdog.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.productivity.master-watchdog.plist
```

## YubiKey Maintenance

### When YubiKey Authentication Breaks
If you get "Sorry, try again" errors with sudo:

```bash
# Check if YubiKey is detected
system_profiler SPUSBDataType | grep -i yubi

# Check PAM configuration  
cat /etc/pam.d/sudo | grep pam_u2f

# Regenerate U2F keys (try both locations)
mkdir -p ~/.config/Yubico
pamu2fcfg > ~/.config/Yubico/u2f_keys

# Alternative location
mkdir -p ~/.yubico  
pamu2fcfg > ~/.yubico/u2f_keys

# Test sudo access
sudo echo "YubiKey working!"
```

### YubiKey Setup Requirements
```bash
# Install pam-u2f if not present
brew install pam-u2f

# Ensure PAM is configured in /etc/pam.d/sudo:
# auth required /opt/homebrew/opt/pam-u2f/lib/pam/pam_u2f.so cue_prompt="Touch your YubiKey to authenticate"
```

### Troubleshooting YubiKey Issues
1. **Physical connection**: Try different USB ports
2. **Generate new keys**: Run `pamu2fcfg` and touch YubiKey when it blinks
3. **Check permissions**: Ensure u2f_keys file is readable by your user
4. **Multiple YubiKeys**: Add multiple keys to u2f_keys file (one per line)
5. **Backup u2f_keys**: Store safely - losing this file breaks authentication

## System Status

Last synced: $(date)

### Current Features
- ✅ Location-based browser blocking (home WiFi)
- ✅ Time-based browser limits (4.5h daily, 45min sessions)  
- ✅ Anti-tampering protection
- ✅ Master watchdog with manager override
- ✅ Auto-start on boot
- ✅ Version control tracking

### Protected Services
- Lock (location-based blocking)
- Timer (time limits)  
- Browser (additional control)
- Configurator (anti-tampering)
- Time (sync protection)
- Profile (profile protection)
- Master-watchdog (supreme protection)

## Development Workflow

1. Make changes to live system files
2. Run `sudo ./sync-from-system.sh` to pull changes
3. Review changes with `git diff`
4. Commit with descriptive message
5. Push to GitHub for backup/sharing
