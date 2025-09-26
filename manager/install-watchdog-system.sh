#!/bin/bash

# Install Master Productivity Watchdog System
# This creates the supreme architecture: Manager > Watchdog > Scripts

echo "🚀 Installing Master Productivity Watchdog System..."
echo "Architecture: Manager > Watchdog > Individual Scripts"
echo ""

# Check sudo
if [[ $EUID -ne 0 ]]; then
    echo "❌ This script requires sudo access"
    echo "Run with: sudo $0"
    exit 1
fi

# Install master watchdog script
echo "📦 Installing master watchdog script..."
cp /Users/arayan/Desktop/master_watchdog.sh /usr/local/productivity/
chmod +x /usr/local/productivity/master_watchdog.sh
chown root:wheel /usr/local/productivity/master_watchdog.sh

# Install watchdog plist
echo "📦 Installing master watchdog daemon..."
cp /Users/arayan/Desktop/com.productivity.master-watchdog.plist /Library/LaunchDaemons/
chmod 644 /Library/LaunchDaemons/com.productivity.master-watchdog.plist
chown root:wheel /Library/LaunchDaemons/com.productivity.master-watchdog.plist

# Update productivity manager
echo "📦 Updating productivity manager..."
cp /Users/arayan/Desktop/productivity-manager.sh /Users/arayan/Desktop/productivity-manager-updated.sh
chmod +x /Users/arayan/Desktop/productivity-manager-updated.sh

# Clean up broken watchdogs
echo "🧹 Cleaning up broken watchdog services..."
launchctl bootout system /Library/LaunchDaemons/com.protection.watchdog.plist 2>/dev/null || true
launchctl bootout system /Library/LaunchDaemons/com.protection.appwatchdog.plist 2>/dev/null || true

# Move broken plists to disabled folder
mkdir -p /Library/LaunchDaemons/disabled
mv /Library/LaunchDaemons/com.protection.watchdog.plist /Library/LaunchDaemons/disabled/ 2>/dev/null || true
mv /Library/LaunchDaemons/com.protection.appwatchdog.plist /Library/LaunchDaemons/disabled/ 2>/dev/null || true

# Start the master watchdog
echo "🛡️ Starting master watchdog..."
launchctl bootstrap system /Library/LaunchDaemons/com.productivity.master-watchdog.plist

# Wait a moment for it to start
sleep 3

echo ""
echo "✅ INSTALLATION COMPLETE!"
echo "========================="
echo ""
echo "🏗️ Architecture deployed:"
echo "   📱 Productivity Manager (Supreme Authority)"
echo "   🛡️ Master Watchdog (Protector Level)"
echo "   ⚙️ Individual Scripts (Protected Level)"
echo ""
echo "🎛️ Use the updated manager:"
echo "   sudo ./productivity-manager-updated.sh status"
echo "   sudo ./productivity-manager-updated.sh stop timer"
echo "   sudo ./productivity-manager-updated.sh start all"
echo ""
echo "🔍 Check watchdog logs:"
echo "   tail -f /var/log/productivity_watchdog.log"
echo ""
echo "✨ The manager can now override watchdog protection!"
echo "
