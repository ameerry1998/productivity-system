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

### Check Status
```bash
sudo ./manager/productivity-manager.sh status
```

### Stop/Start Services  
```bash
sudo ./manager/productivity-manager.sh stop timer
sudo ./manager/productivity-manager.sh start all
```

### Sync Latest Changes
```bash
# Run this before committing to capture current system state
sudo ./sync-from-system.sh
```

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
