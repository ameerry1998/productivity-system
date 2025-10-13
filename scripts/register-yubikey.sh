#!/bin/bash

# YubiKey Re-registration Script
# Run this whenever YubiKey stops working for sudo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  YubiKey Re-registration for Sudo Access"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  This will register your current YubiKey for sudo access"
echo ""
read -p "Press Enter to continue (Ctrl+C to cancel)..."
echo ""

# Check if running with password sudo (before YubiKey requirement)
if ! sudo -v 2>/dev/null; then
    echo "❌ Cannot verify sudo access"
    echo "If locked out, boot into Recovery Mode and restore /etc/pam.d/sudo.backup"
    exit 1
fi

echo "Step 1/3: Insert your YubiKey now..."
read -p "Press Enter when YubiKey is inserted..."
echo ""

echo "Step 2/3: Registering YubiKey (touch it when it blinks)..."
pamu2fcfg > /tmp/u2f_keys_new
if [ ! -s /tmp/u2f_keys_new ]; then
    echo "❌ Registration failed - no data received"
    rm /tmp/u2f_keys_new
    exit 1
fi
echo "✅ YubiKey registered"
echo ""

echo "Step 3/3: Installing to system..."
sudo mkdir -p /etc/Yubico
sudo mv /tmp/u2f_keys_new /etc/Yubico/u2f_keys
sudo chmod 644 /etc/Yubico/u2f_keys
echo "✅ Installation complete"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Testing YubiKey..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Registered key:"
cat /etc/Yubico/u2f_keys
echo ""
echo "✅ Done! Your YubiKey is now registered for sudo access."
echo ""
echo "Next: Configure /etc/pam.d/sudo to require it"
echo "Run: sudo nano /etc/pam.d/sudo"

