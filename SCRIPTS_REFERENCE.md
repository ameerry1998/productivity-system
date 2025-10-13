# 📊 Complete Productivity System Inventory

**Last Updated:** October 13, 2025  
**Status:** Fully Operational ✅

---

## 🎯 **TIER 1: CORE ENFORCEMENT (Active Protection)**

These scripts are your main productivity enforcers. **DO NOT DISABLE without good reason.**

### **screen_lock.sh** ✅ CRITICAL
- **Purpose:** Browser Blocker (Home Detection)
- **What it does:** Kills all 25 browsers when home WiFi detected
- **How:** Uses Swift/CoreWLAN for unredacted SSID scanning
- **Runs:** Every 3 seconds at home, 5 seconds away
- **Protects:** Your focus by blocking distractions at home
- **LaunchDaemon:** `com.productivity.lock`
- **Log:** `/var/log/screen_lock.log`

### **browser_timer.sh** ✅ CRITICAL
- **Purpose:** Time Limits & Session Management
- **What it does:** 
  - Enforces 4.5-hour daily browser limit
  - 45-minute session limit (25-min break required)
  - Blocks browsers 5:00 AM - 10:40 AM
- **How:** Tracks via `.browser_timer`, `.browser_hourly`, `.browser_break` files
- **Runs:** Continuously (checks every second)
- **Protects:** You from excessive browsing
- **LaunchDaemon:** `com.productivity.timer`
- **Log:** `/var/log/browser_timer.log`

### **home_usage_limiter.sh** ✅ CRITICAL
- **Purpose:** Home Usage Cap
- **What it does:**
  - Tracks cumulative laptop time at home
  - 4-hour daily limit
  - **Hard screen lock** when exceeded (password required)
  - Notifications at 2h, 1h, 30m, 10m remaining
- **How:** Writes to `/var/log/home_usage.timer`, uses same network detection as screen_lock
- **Runs:** Continuously (checks every 5 seconds)
- **Protects:** Work-life balance, prevents laptop overuse at home
- **LaunchDaemon:** `com.productivity.home-limiter`
- **Log:** `/var/log/home_usage.log`

---

## 🛡️ **TIER 2: SYSTEM PROTECTION (Anti-Tampering)**

These protect the productivity system itself from being disabled or manipulated.

### **master_watchdog.sh** ✅ CRITICAL
- **Purpose:** Guardian of All Services
- **What it does:**
  - Monitors all 7 productivity services
  - Auto-restarts crashed/killed scripts within 15 seconds
  - Enforces productivity-manager commands
  - **Clears all overrides on boot** (bulletproof restart)
  - Checks for plist corruption and restores from backup
- **How:** 15-second check cycle, validates PIDs (not just launchctl state)
- **Runs:** Every 15 seconds, forever
- **Protects:** The entire system - "who watches the watchers?"
- **LaunchDaemon:** `com.productivity.master-watchdog`
- **Self-Protection:** KeepAlive=true (launchd restarts if killed)
- **Immutable:** Files have `uchg` flag
- **Log:** `/var/log/productivity_watchdog.log`

### **time_protection.sh** ⚠️ IMPORTANT
- **Purpose:** Time Manipulation Blocker
- **What it does:** Ensures "Set date and time automatically" stays ON
- **How:** Checks system time settings every second
- **Runs:** Every 1 second
- **Protects:** Prevents cheating time-based limits by changing system clock
- **LaunchDaemon:** `com.productivity.time-protection`
- **Log:** `/var/log/time_protection.log`

### **block_apple_configurator.sh** ⚠️ IMPORTANT
- **Purpose:** Anti-Tampering
- **What it does:** Kills Apple Configurator (iOS device management tool)
- **How:** Continuously monitors and kills "Apple Configurator" processes
- **Runs:** Continuously
- **Protects:** Prevents using Configurator to tamper with system
- **LaunchDaemon:** `com.productivity.configurator-blocker`
- **Log:** `/var/log/configurator_blocker.log`

---

## 📦 **TIER 3: SUPPORT TOOLS (Passive/Deprecated)**

These are old or redundant. Safe to remove.

### **browser_control.sh** ❌ REDUNDANT
- **Purpose:** Backup browser control
- **Status:** Redundant with screen_lock.sh
- **Action:** Consider disabling or removing

### **geofence_monitor.sh** ❌ DEPRECATED
- **Purpose:** Old location detection
- **Status:** Replaced by screen_lock.sh SSID detection
- **Action:** Safe to delete

### **learn_home_network.sh** ❌ DEPRECATED
- **Purpose:** Teach gateway MAC addresses
- **Status:** Deprecated after switching to SSID detection
- **Action:** Safe to delete

---

## 🔧 **TIER 4: MANAGEMENT & UTILITIES**

Command-line tools for managing the system.

### **productivity-manager.sh**
- **Purpose:** Central Control Interface
- **Commands:**
  - `productivity-manager status` - Check all services
  - `productivity-manager start [service]` - Start service
  - `productivity-manager stop [service]` - Stop service (requires sudo+YubiKey)
  - `productivity-manager restart [service]` - Restart service
  - `productivity-manager reload all` - Reload scripts without breaking watchdog
  - `productivity-manager logs [service]` - View logs
  - `productivity-manager live` - Live log watching
- **Location:** `/usr/local/bin/productivity-manager` (symlink)
- **Immutable:** Yes (`uchg` flag)

### **productivity-reload**
- **Purpose:** Hot Reload Scripts
- **What it does:** Unloads & reloads all LaunchDaemons EXCEPT watchdog
- **When to use:** After manually editing scripts
- **Location:** `/usr/local/bin/productivity-reload`

### **productivity-logs**
- **Purpose:** Unified Log Viewer
- **Commands:**
  - `productivity-logs stats` - Usage statistics
  - `productivity-logs live` - Real-time log watching
  - `productivity-logs today` - Today's activity
  - `productivity-logs search <term>` - Search logs
  - `productivity-logs tail <service>` - Tail specific log
- **Location:** `/usr/local/bin/productivity-logs`

### **get-network-ssids**
- **Purpose:** Network Scanner
- **What it does:** Scans for WiFi networks in range (unredacted SSIDs)
- **How:** Swift/CoreWLAN inline compilation (~0.2 seconds)
- **Used by:** screen_lock.sh, home_usage_limiter.sh
- **No cache:** Real-time detection for reliability
- **Location:** `/usr/local/bin/get-network-ssids`

### **HomeTimerMenuBar**
- **Purpose:** Menu Bar Time Display
- **What it does:** Shows remaining home usage time in menu bar
- **How:** Reads from `/var/log/home_usage.timer`, updates every 30 seconds
- **Type:** Swift compiled binary
- **LaunchAgent:** `com.productivity.home-timer-menubar` (user-level)
- **Location:** `/usr/local/bin/HomeTimerMenuBar`

### **register-yubikey**
- **Purpose:** YubiKey Re-registration
- **What it does:** Re-registers YubiKey for sudo access
- **When to use:** When YubiKey "forgets" (counter changes after unplug/replug)
- **How to run:** `register-yubikey` (follow prompts, touch key when it blinks)
- **Location:** `/usr/local/bin/register-yubikey`
- **See:** YUBIKEY_SETUP.md for full instructions

---

## 📋 **ACTIVE SERVICES SUMMARY**

| Service | Script | Status | Protected? |
|---------|--------|--------|------------|
| lock | screen_lock.sh | ✅ Running | ✅ Watchdog |
| timer | browser_timer.sh | ✅ Running | ✅ Watchdog |
| home-limiter | home_usage_limiter.sh | ✅ Running | ✅ Watchdog |
| time | time_protection.sh | ✅ Running | ✅ Watchdog |
| configurator | block_apple_configurator.sh | ✅ Running | ✅ Watchdog |
| browser | browser_control.sh | ✅ Running | ✅ Watchdog |
| master-watchdog | master_watchdog.sh | ✅ Running | 🛡️ Self (launchd) |
| home-timer-menubar | HomeTimerMenuBar | ✅ Running | ⚠️ User-level |

---

## 🎯 **BROWSER LIST (25 Total)**

**Blocked Browsers:**
- Safari, Arc, Google Chrome, Firefox, Microsoft Edge
- Opera, Brave Browser, Vivaldi, Session, Tor Browser
- DuckDuckGo Privacy Browser, Chromium
- Safari Technology Preview, Firefox Developer Edition
- Google Chrome Canary, Opera GX
- Mullvad Browser, LibreWolf, Waterfox
- Orion, SigmaOS, Sidekick
- Min, qutebrowser, Ungoogled Chromium, Iridium Browser

**Whitelisted Apps:**
- Xcode (for development)
- Simulator (iOS development)

---

## 🔐 **SECURITY ARCHITECTURE**

### **YubiKey Protection:**
- `/etc/pam.d/sudo` configured for YubiKey-only authentication
- **NO Touch ID bypass**
- **NO password fallback**
- Physical YubiKey presence = REQUIRED for sudo
- Keys stored: `/etc/Yubico/u2f_keys`
- Backup configs: `/etc/pam.d/sudo.backup*`

### **Immutable Files:**
- Watchdog plist: `chflags uchg`
- Watchdog script: `chflags uchg`
- Manager script: `chflags uchg`

### **Protection Layers:**
1. **LaunchDaemon KeepAlive** - OS restarts services
2. **Master Watchdog** - Monitors and restarts scripts
3. **Immutable flags** - Prevents accidental deletion
4. **YubiKey sudo** - Physical key required for changes

---

## 📁 **FILE LOCATIONS**

### **Scripts:**
- `/usr/local/productivity/*.sh` - All productivity scripts

### **LaunchDaemons:**
- `/Library/LaunchDaemons/com.productivity.*.plist` - System services

### **LaunchAgents:**
- `~/Library/LaunchAgents/com.productivity.home-timer-menubar.plist` - Menu bar app

### **Binaries:**
- `/usr/local/bin/productivity-*` - Management tools
- `/usr/local/bin/get-network-ssids` - Network scanner
- `/usr/local/bin/HomeTimerMenuBar` - Menu bar app
- `/usr/local/bin/register-yubikey` - YubiKey helper

### **Logs:**
- `/var/log/screen_lock.log`
- `/var/log/browser_timer.log`
- `/var/log/home_usage.log`
- `/var/log/productivity_watchdog.log`
- `/var/log/time_protection.log`
- `/var/log/configurator_blocker.log`

### **State Files:**
- `/var/log/home_usage.timer` - Home usage tracking
- `~/.browser_timer` - Daily browser usage
- `~/.browser_hourly` - Session usage
- `~/.browser_break` - Break timer

---

## 🚀 **QUICK COMMANDS**

```bash
# Check status
productivity-manager status

# Reload all scripts (after editing)
productivity-reload

# View live logs
productivity-logs live

# Check home usage time
cat /var/log/home_usage.timer

# Re-register YubiKey
register-yubikey

# Test watchdog (kill a service)
sudo pkill -f browser_timer.sh
# Wait 20 seconds, check if restarted:
ps aux | grep browser_timer.sh
```

---

## ⚠️ **EMERGENCY RECOVERY**

If completely locked out:
1. Boot into Recovery Mode (Cmd+R at startup)
2. Open Terminal
3. Restore PAM config:
   ```bash
   cp /Volumes/Macintosh\ HD/etc/pam.d/sudo.backup* /Volumes/Macintosh\ HD/etc/pam.d/sudo
   ```
4. Reboot normally

---

## 📊 **SYSTEM HEALTH CHECK**

Run this to verify everything is working:
```bash
productivity-manager status
productivity-logs stats
ps aux | grep -E "screen_lock|browser_timer|home_usage|watchdog" | grep -v grep | wc -l
# Should show 5+ processes running
```

---

**For detailed setup instructions, see:** `FRESH_INSTALL_GUIDE.md`  
**For session logs and debugging history, see:** `SESSION_LOG_*.md`  
**For YubiKey setup, see:** `YUBIKEY_SETUP.md` (to be created)

