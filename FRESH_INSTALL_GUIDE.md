# Fresh Installation Guide - Complete System Restore

This guide walks you through setting up the entire productivity system on a **brand new Mac** from scratch.

## Prerequisites

- New Mac with macOS
- Your YubiKey
- This GitHub repository downloaded

## Quick Install (Recommended)

```bash
# 1. Clone the repository
git clone git@github.com:ameerry1998/productivity-system.git
cd productivity-system

# 2. Run the installation script
sudo bash INSTALL.sh

# 3. Done! Skip to "Configuration" section below
```

---

## Manual Installation (Step-by-Step)

If you prefer to understand each step or if the automated install fails:

### Step 1: Install Homebrew (if needed)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 2: Install pam-u2f (for YubiKey)

```bash
brew install pam-u2f
```

### Step 3: Create System Directories

```bash
sudo mkdir -p /usr/local/productivity
sudo mkdir -p /usr/local/ProductivityBackups
sudo mkdir -p /tmp/productivity-manager-overrides
```

### Step 4: Copy Scripts

```bash
cd productivity-system
sudo cp scripts/*.sh /usr/local/productivity/
sudo chmod 755 /usr/local/productivity/*.sh
```

### Step 5: Copy LaunchDaemons

```bash
sudo cp launch-daemons/*.plist /Library/LaunchDaemons/
sudo chmod 644 /Library/LaunchDaemons/com.productivity.*.plist
```

### Step 6: Install Command-Line Tools

```bash
sudo ln -sf /usr/local/productivity/productivity-manager.sh /usr/local/bin/productivity-manager
sudo cp scripts/productivity-logs.sh /usr/local/bin/productivity-logs
sudo chmod 755 /usr/local/bin/productivity-logs
```

### Step 7: Create Reload Helper

```bash
sudo bash -c 'cat > /usr/local/bin/productivity-reload << '\''EOF'\''
#!/bin/bash
echo "🔄 Reloading productivity scripts (keeping watchdog alive)..."
for plist in lock timer browser configurator-blocker time-protection profile-protection home-limiter; do
    sudo launchctl unload "/Library/LaunchDaemons/com.productivity.$plist.plist" 2>/dev/null
done
sleep 2
for plist in lock timer browser configurator-blocker time-protection profile-protection home-limiter; do
    sudo launchctl load "/Library/LaunchDaemons/com.productivity.$plist.plist" 2>/dev/null
done
echo "✅ Scripts reloaded!"
productivity-manager status
EOF'

sudo chmod 755 /usr/local/bin/productivity-reload
```

### Step 8: Compile and Install Menu Bar App

```bash
cd productivity-system
swiftc HomeTimerMenuBar.swift -o HomeTimerMenuBar
sudo cp HomeTimerMenuBar /usr/local/bin/
sudo chmod 755 /usr/local/bin/HomeTimerMenuBar

# Install user LaunchAgent
mkdir -p ~/Library/LaunchAgents
cp com.productivity.home-timer-menubar.plist ~/Library/LaunchAgents/
```

### Step 9: Protect Critical Files

```bash
sudo chflags uchg /usr/local/productivity/productivity-manager.sh
```

### Step 10: Start All Services

```bash
# Start watchdog first
sudo launchctl load /Library/LaunchDaemons/com.productivity.master-watchdog.plist

# Wait for watchdog to start
sleep 3

# Load all other services (watchdog will protect them)
sudo launchctl load /Library/LaunchDaemons/com.productivity.*.plist

# Start menu bar app
launchctl load ~/Library/LaunchAgents/com.productivity.home-timer-menubar.plist
```

---

## Configuration

### 1. Set Your Home WiFi Networks

Edit the home networks list:
```bash
sudo nano /usr/local/productivity/screen_lock.sh
```

Find this section and add your network names:
```bash
HOME_NETWORKS=(
    "YOUR_WIFI_NAME"
    "YOUR_WIFI_5G_NAME" 
    "ANOTHER_NETWORK"
)
```

### 2. Learn Your Home Gateway MAC (Important!)

When you're **at home**, run:
```bash
sudo /usr/local/productivity/learn_home_network.sh
```

This saves your home router's MAC address for reliable detection.

### 3. Reload Scripts to Apply Changes

```bash
productivity-reload
```

---

## YubiKey Setup

### 1. Register Your YubiKey

```bash
# Create directory
sudo mkdir -p /etc/Yubico

# Register your YubiKey (insert it first)
pamu2fcfg > ~/u2f_keys_temp
sudo mv ~/u2f_keys_temp /etc/Yubico/u2f_keys
sudo chmod 644 /etc/Yubico/u2f_keys
```

### 2. Configure PAM for sudo

**⚠️ CRITICAL: Get this right or you'll lose sudo access!**

```bash
# Backup current config
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.backup

# Edit sudo PAM config
sudo nano /etc/pam.d/sudo
```

Replace contents with:
```
# sudo: auth account password session
auth       sufficient     pam_tid.so
auth       required       pam_u2f.so authfile=/etc/Yubico/u2f_keys cue prompt="Touch your YubiKey to authenticate" debug
auth       sufficient     pam_smartcard.so
auth       required       pam_opendirectory.so
account    required       pam_permit.so
password   required       pam_deny.so
session    required       pam_permit.so
```

### 3. Test YubiKey

**Open a NEW terminal** and test:
```bash
sudo ls
```

You should be prompted to touch your YubiKey.

**If it doesn't work:**
```bash
# Restore backup
sudo cp /etc/pam.d/sudo.backup /etc/pam.d/sudo
```

---

## Verification

Check everything is running:

```bash
# View system status
productivity-manager status

# Should show all ✅ Running:
# lock, timer, browser, configurator, time, profile, home-limiter, master-watchdog

# View usage stats
productivity-logs stats

# Check menu bar
# Look for 🏠 icon in top-right menu bar
```

---

## Common Commands

```bash
# View all logs in real-time
productivity-logs live

# Check usage statistics
productivity-logs stats

# Reload scripts after editing
productivity-reload

# Stop a service (requires YubiKey)
sudo productivity-manager stop lock

# Start all services
sudo productivity-manager start all

# View service status
productivity-manager status
```

---

## Troubleshooting

### Scripts not running?

```bash
# Check processes
ps aux | grep -E "(screen_lock|browser_timer|home_usage_limiter|master_watchdog)" | grep -v grep

# Check LaunchDaemon status
sudo launchctl list | grep productivity

# View watchdog logs
sudo tail -50 /var/log/productivity_watchdog.log
```

### Can't get sudo access?

If YubiKey setup failed and you're locked out:

1. Reboot Mac
2. Hold `Cmd + R` to enter Recovery Mode
3. Terminal > `csrutil disable` (disable SIP temporarily)
4. Reboot normally
5. Edit `/etc/pam.d/sudo` to restore basic password auth
6. Re-enable SIP in Recovery Mode

### Menu bar app not showing?

```bash
# Check if running
ps aux | grep HomeTimerMenuBar

# Restart it
launchctl unload ~/Library/LaunchAgents/com.productivity.home-timer-menubar.plist
launchctl load ~/Library/LaunchAgents/com.productivity.home-timer-menubar.plist
```

### Watchdog not protecting scripts?

```bash
# Check watchdog is running
ps aux | grep master_watchdog

# View recent watchdog activity
sudo tail -100 /var/log/productivity_watchdog.log

# Manually restart watchdog
sudo launchctl load /Library/LaunchDaemons/com.productivity.master-watchdog.plist
```

---

## What Gets Protected

| Component | What It Does | Daily Limit |
|-----------|--------------|-------------|
| **Browser Blocker** | Kills browsers at home | Unlimited blocks |
| **Browser Timer** | Limits browser usage | 4.5h daily, 45min sessions |
| **Home Usage Limiter** | Locks screen after home use | 4h cumulative at home |
| **Time Protection** | Prevents time changes | N/A |
| **Configurator Blocker** | Blocks Apple Configurator | N/A |
| **Master Watchdog** | Restarts all scripts if killed | N/A |
| **Menu Bar App** | Shows remaining home time | N/A |

---

## System Architecture

```
┌─────────────────────────────────────────────┐
│         Master Watchdog (Bulletproof)       │
│  - Monitors all 7 services every 15 sec     │
│  - Restores deleted plists from backup      │
│  - Requires sudo to disable                 │
│  - Clears overrides on boot (always restart)│
└─────────────────────────────────────────────┘
                      │
        ┌─────────────┼─────────────┬──────────┐
        │             │             │          │
┌───────▼────┐  ┌────▼─────┐  ┌───▼────┐  ┌──▼──────┐
│  Browser   │  │  Browser │  │  Home  │  │  Time   │
│  Blocker   │  │  Timer   │  │ Limiter│  │ Protect │
│  (home)    │  │ (4.5h)   │  │  (4h)  │  │         │
└────────────┘  └──────────┘  └────────┘  └─────────┘
```

---

## File Locations Reference

```
/usr/local/productivity/           # All scripts
├── screen_lock.sh                 # Browser blocker at home
├── browser_timer.sh               # 4.5h daily browser limit
├── home_usage_limiter.sh          # 4h home laptop limit
├── master_watchdog.sh             # Bulletproof protection
├── time_protection.sh             # Time tamper prevention
├── block_apple_configurator.sh    # Config blocker
├── browser_control.sh             # Additional control
├── productivity-manager.sh        # Management interface
├── learn_home_network.sh          # MAC address learner
└── .home_gateway_macs             # Saved home MACs

/Library/LaunchDaemons/            # System services
├── com.productivity.*.plist       # All 8 service configs

/usr/local/bin/                    # Commands
├── productivity-manager           # Main management tool
├── productivity-logs              # Log viewer
├── productivity-reload            # Reload helper
└── HomeTimerMenuBar               # Menu bar app

/var/log/                          # Logs
├── screen_lock.log
├── browser_timer.log
├── home_usage.log
├── productivity_watchdog.log
└── *.log

/etc/Yubico/                       # YubiKey
└── u2f_keys                       # YubiKey registration
```

---

## Support

If you run into issues:

1. Check logs: `productivity-logs live`
2. Check status: `productivity-manager status`
3. View watchdog: `sudo tail -100 /var/log/productivity_watchdog.log`
4. Restart all: `productivity-reload`

**The system is designed to be bulletproof - it should just work!** 🛡️

