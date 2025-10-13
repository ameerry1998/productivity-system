#!/bin/bash

# Productivity System - Complete Installation Script
# Run this to set up the entire system on a fresh Mac

set -e  # Exit on any error

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║   Productivity System - Complete Installation               ║"
echo "║   This will install ALL productivity scripts and services   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run with sudo"
   echo "Usage: sudo bash INSTALL.sh"
   exit 1
fi

echo "Step 1/8: Creating directories..."
mkdir -p /usr/local/productivity
mkdir -p /usr/local/ProductivityBackups
mkdir -p /tmp/productivity-manager-overrides
echo "✅ Directories created"
echo ""

echo "Step 2/8: Installing productivity scripts..."
cp scripts/*.sh /usr/local/productivity/
chmod 755 /usr/local/productivity/*.sh
echo "✅ Scripts installed to /usr/local/productivity/"
echo ""

echo "Step 3/8: Installing LaunchDaemons..."
cp launch-daemons/*.plist /Library/LaunchDaemons/
chmod 644 /Library/LaunchDaemons/com.productivity.*.plist
echo "✅ LaunchDaemons installed"
echo ""

echo "Step 4/8: Installing command-line tools..."
ln -sf /usr/local/productivity/productivity-manager.sh /usr/local/bin/productivity-manager
cp scripts/productivity-logs.sh /usr/local/bin/productivity-logs
cp scripts/get-network-ssids.sh /usr/local/bin/get-network-ssids
chmod 755 /usr/local/bin/productivity-logs
chmod 755 /usr/local/bin/get-network-ssids
echo "✅ Command-line tools installed (productivity-manager, productivity-logs, get-network-ssids)"
echo ""

echo "Step 5/8: Installing menu bar app..."
if [ -f "HomeTimerMenuBar" ]; then
    cp HomeTimerMenuBar /usr/local/bin/
    chmod 755 /usr/local/bin/HomeTimerMenuBar
    
    # Install user LaunchAgent (as the actual user, not root)
    REAL_USER=$(stat -f "%Su" .)
    USER_HOME=$(eval echo "~$REAL_USER")
    
    sudo -u "$REAL_USER" mkdir -p "$USER_HOME/Library/LaunchAgents"
    cp com.productivity.home-timer-menubar.plist "$USER_HOME/Library/LaunchAgents/"
    chown "$REAL_USER:staff" "$USER_HOME/Library/LaunchAgents/com.productivity.home-timer-menubar.plist"
    
    echo "✅ Menu bar app installed"
else
    echo "⚠️  Menu bar app not found (optional - compile from HomeTimerMenuBar.swift)"
fi
echo ""

echo "Step 6/8: Creating home network configuration..."
if [ ! -f "/usr/local/productivity/.home_gateway_macs" ]; then
    echo "# Add your home gateway MAC addresses here (one per line)" > /usr/local/productivity/.home_gateway_macs
    chmod 600 /usr/local/productivity/.home_gateway_macs
fi
echo "✅ Configuration files ready"
echo ""

echo "Step 7/8: Protecting critical files..."
chflags uchg /usr/local/productivity/productivity-manager.sh
echo "✅ Critical files protected with immutable flag"
echo ""

echo "Step 8/8: Starting all services..."
launchctl load /Library/LaunchDaemons/com.productivity.master-watchdog.plist 2>/dev/null || true
sleep 2
launchctl load /Library/LaunchDaemons/com.productivity.*.plist 2>/dev/null || true
sleep 3
echo "✅ Services started"
echo ""

# Start menu bar app for user
if [ -f "/usr/local/bin/HomeTimerMenuBar" ]; then
    REAL_USER=$(stat -f "%Su" .)
    USER_HOME=$(eval echo "~$REAL_USER")
    sudo -u "$REAL_USER" launchctl load "$USER_HOME/Library/LaunchAgents/com.productivity.home-timer-menubar.plist" 2>/dev/null || true
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Installation Complete!                    ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Checking status..."
echo ""
productivity-manager status
echo ""
echo "Next steps:"
echo "1. Edit /usr/local/productivity/screen_lock.sh to set your home WiFi names"
echo "2. Run: sudo /usr/local/productivity/learn_home_network.sh (when at home)"
echo "3. Set up YubiKey authentication (see YUBIKEY_SETUP.md)"
echo "4. Use 'productivity-manager' to control services"
echo "5. Use 'productivity-logs stats' to view usage"
echo ""
echo "All done! 🎉"

