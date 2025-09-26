#!/bin/bash

# Sync Productivity System Files to Git Repository
# This script pulls the current state of all productivity files from the system
# Run this before committing to capture the latest changes

echo "🔄 Syncing productivity system files from live system..."

# Get the repository root directory
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "Repository: $REPO_DIR"

# Sync productivity scripts
echo "📁 Syncing scripts from /usr/local/productivity/..."
if [ -d "/usr/local/productivity" ]; then
    cp /usr/local/productivity/*.sh "$REPO_DIR/scripts/" 2>/dev/null || echo "   ⚠️  Some scripts may need sudo to copy"
    echo "   ✅ Copied script files"
else
    echo "   ❌ /usr/local/productivity not found"
fi

# Sync launch daemons
echo "📁 Syncing LaunchDaemons from /Library/LaunchDaemons/..."
sudo cp /Library/LaunchDaemons/com.productivity.*.plist "$REPO_DIR/launch-daemons/" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✅ Copied LaunchDaemon files"
else
    echo "   ❌ Failed to copy LaunchDaemon files (sudo required)"
fi

# Sync manager script
echo "📁 Syncing manager script..."
if [ -f "/Users/arayan/Desktop/productivity-manager-updated.sh" ]; then
    cp "/Users/arayan/Desktop/productivity-manager-updated.sh" "$REPO_DIR/manager/productivity-manager.sh"
    echo "   ✅ Copied manager script"
else
    echo "   ⚠️  Manager script not found"
fi

# Sync install scripts
echo "📁 Syncing install/helper scripts..."
for script in "/Users/arayan/Desktop/reactivate_all.sh" "/Users/arayan/Desktop/install-watchdog-system.sh"; do
    if [ -f "$script" ]; then
        cp "$script" "$REPO_DIR/manager/"
        echo "   ✅ Copied $(basename "$script")"
    fi
done

# Create sample log entries (last 50 lines)
echo "📁 Creating log samples..."
if [ -f "/var/log/productivity_watchdog.log" ]; then
    tail -50 /var/log/productivity_watchdog.log > "$REPO_DIR/logs/watchdog-sample.log" 2>/dev/null
    echo "   ✅ Copied watchdog log sample"
fi

# Create system status snapshot
echo "📁 Creating system status snapshot..."
{
    echo "# Productivity System Status - $(date)"
    echo ""
    echo "## Running Services:"
    launchctl list | grep com.productivity
    echo ""
    echo "## File Permissions:"
    ls -la /usr/local/productivity/*.sh 2>/dev/null
    echo ""
    echo "## LaunchDaemons:"
    ls -la /Library/LaunchDaemons/com.productivity.*.plist 2>/dev/null
} > "$REPO_DIR/logs/system-status.txt"

echo "   ✅ Created system status snapshot"
echo ""
echo "✅ Sync complete! Files are now ready for Git operations."
echo ""
echo "💡 Next steps:"
echo "   cd /Users/arayan/Desktop/productivity-system-repo"
echo "   git add ."
echo "   git commit -m 'Initial productivity system snapshot'"
echo "   # Then push to GitHub"
