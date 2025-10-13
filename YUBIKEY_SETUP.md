# 🔐 YubiKey Setup Guide

**Purpose:** Configure YubiKey-only sudo authentication (no password/Touch ID fallback)

---

## ⚠️ **CRITICAL WARNING**

This configuration **removes ALL sudo fallbacks**:
- ❌ No password will work
- ❌ No Touch ID will work
- ✅ ONLY YubiKey works

**If YubiKey is lost/broken/unavailable:**
- You will be **COMPLETELY LOCKED OUT** of sudo
- Recovery Mode will be your **ONLY way back in**

**Keep YubiKey safe!** (User keeps it with girlfriend as intentional friction)

---

## 📋 **Prerequisites**

1. **YubiKey** (physical device)
2. **pam-u2f installed:**
   ```bash
   brew install pam-u2f
   ```
3. **Backup access method** (know how to boot Recovery Mode)

---

## 🚀 **Initial Setup**

### **Step 1: Register Your YubiKey**

```bash
# Run the registration script
register-yubikey
```

**What it does:**
1. Prompts you to insert YubiKey
2. Runs `pamu2fcfg` (touch YubiKey when it blinks)
3. Saves registration to `/etc/Yubico/u2f_keys`
4. Sets correct permissions (644, owned by root)

**Manual Method:**
```bash
# If script fails, register manually:
pamu2fcfg > /tmp/u2f_keys_new
sudo mkdir -p /etc/Yubico
sudo mv /tmp/u2f_keys_new /etc/Yubico/u2f_keys
sudo chmod 644 /etc/Yubico/u2f_keys
```

---

### **Step 2: Backup Current PAM Config**

```bash
sudo cp /etc/pam.d/sudo /etc/pam.d/sudo.backup.$(date +%Y%m%d)
```

**CRITICAL:** Always backup before editing!

---

### **Step 3: Configure PAM for YubiKey-Only**

Edit `/etc/pam.d/sudo`:
```bash
sudo nano /etc/pam.d/sudo
```

**Replace contents with:**
```
# sudo: auth account password session
auth       required       /opt/homebrew/opt/pam-u2f/lib/pam/pam_u2f.so authfile=/etc/Yubico/u2f_keys
account    required       pam_permit.so
password   required       pam_deny.so
session    required       pam_permit.so
```

**Key points:**
- `auth required` = YubiKey is **REQUIRED** (no fallback)
- No `pam_tid.so` = No Touch ID
- No `pam_opendirectory.so` = No password
- Path must be exact: `/opt/homebrew/opt/pam-u2f/lib/pam/pam_u2f.so`

Save and exit (Ctrl+X, Y, Enter in nano)

---

### **Step 4: Test IMMEDIATELY**

**IMPORTANT:** Keep current terminal open!

Open a **NEW terminal** and test:
```bash
sudo ls /etc
# Should prompt: "Touch your YubiKey to authenticate"
# Touch YubiKey (it will blink)
# Should work!
```

**If it works:** ✅ Success!  
**If it fails:** ❌ Restore backup immediately (in original terminal):
```bash
sudo cp /etc/pam.d/sudo.backup.YYYYMMDD /etc/pam.d/sudo
```

---

## 🔄 **The "Forgetting" Problem**

### **What Happens:**

YubiKey has an internal counter that increments each use. Sometimes when you:
- Unplug and replug the key
- Use it on another computer
- Restart the Mac

...the counter changes and PAM thinks it's a **different key**, causing authentication to fail.

### **Symptoms:**

```bash
sudo ls
# Prompt appears, you touch YubiKey
# Error: "Authentication failed"
# Even though key is working physically
```

### **Solution:**

**Re-register the YubiKey:**
```bash
register-yubikey
```

This creates a fresh registration with the current counter state.

**How often:** Only when YubiKey stops working (varies, could be weeks/months)

---

## 📝 **The register-yubikey Script**

**Location:** `/usr/local/bin/register-yubikey`

**What it does:**
1. Checks if sudo is accessible (needs current password/working YubiKey)
2. Prompts for YubiKey insertion
3. Runs `pamu2fcfg` to generate new registration
4. Installs to `/etc/Yubico/u2f_keys`
5. Shows confirmation

**When to use:**
- After first install
- When YubiKey stops working
- After using key on another computer
- After Mac OS updates (rarely needed)

**Usage:**
```bash
register-yubikey
# Follow prompts
# Touch YubiKey when it blinks
# Done!
```

---

## 🆘 **Emergency Recovery**

### **Scenario 1: YubiKey Lost/Broken**

**Boot into Recovery Mode:**
1. Restart Mac
2. Hold **Cmd+R** during boot
3. Wait for Recovery Mode to load
4. Open Terminal (Utilities menu → Terminal)

**Restore password authentication:**
```bash
# Mount main drive
diskutil list
# Find your main drive (usually disk1s1 or disk3s1)

# Mount it
mkdir /tmp/main
mount -t apfs /dev/disk3s1 /tmp/main

# Restore backup PAM config
cp /tmp/main/etc/pam.d/sudo.backup.* /tmp/main/etc/pam.d/sudo

# Or manually fix it
nano /tmp/main/etc/pam.d/sudo
```

**Safe PAM config (password + Touch ID):**
```
# sudo: auth account password session
auth       sufficient     pam_tid.so
auth       required       pam_opendirectory.so
account    required       pam_permit.so
password   required       pam_deny.so
session    required       pam_permit.so
```

Save, unmount, reboot:
```bash
umount /tmp/main
reboot
```

---

### **Scenario 2: YubiKey "Forgot" Registration**

If you have password access still:
```bash
register-yubikey
```

If locked out completely:
- Follow Scenario 1 (Recovery Mode)
- Or temporarily restore password auth, then re-register

---

## 🔍 **Troubleshooting**

### **Problem: "Authentication failed" with YubiKey**

**Check 1: Is key registered?**
```bash
cat /etc/Yubico/u2f_keys
# Should show: username:long_key_string
```

**Check 2: PAM config correct?**
```bash
cat /etc/pam.d/sudo
# Should have: auth required .../pam_u2f.so authfile=/etc/Yubico/u2f_keys
```

**Check 3: File permissions?**
```bash
ls -la /etc/Yubico/u2f_keys
# Should be: -rw-r--r-- root wheel
```

**Fix:** Re-register
```bash
register-yubikey
```

---

### **Problem: YubiKey not blinking**

**Check 1: Is it plugged in?**
```bash
system_profiler SPUSBDataType | grep -i yubi
```

**Check 2: Try different USB port**

**Check 3: pam-u2f installed?**
```bash
ls -la /opt/homebrew/opt/pam-u2f/lib/pam/pam_u2f.so
```

---

### **Problem: "Operation not permitted" in Recovery Mode**

Some Macs have SIP (System Integrity Protection) preventing `/etc` edits even in Recovery.

**Solution:**
1. In Recovery Mode Terminal:
   ```bash
   csrutil disable
   ```
2. Reboot
3. Edit `/etc/pam.d/sudo` normally
4. Re-enable SIP:
   ```bash
   csrutil enable
   ```

---

## 📚 **Additional Resources**

- **Yubico PAM-U2F:** https://developers.yubico.com/pam-u2f/
- **macOS Recovery Mode:** Hold Cmd+R at startup
- **PAM Configuration:** `man pam` in Terminal

---

## ✅ **Verification Checklist**

After setup, verify:
- [ ] YubiKey registered: `cat /etc/Yubico/u2f_keys`
- [ ] PAM configured: `cat /etc/pam.d/sudo`
- [ ] Backup exists: `ls /etc/pam.d/sudo.backup*`
- [ ] sudo works with YubiKey: `sudo ls`
- [ ] sudo FAILS without YubiKey: Unplug key, try `sudo ls` (should fail)
- [ ] register-yubikey script installed: `which register-yubikey`
- [ ] Know how to boot Recovery Mode: Cmd+R at startup

---

## 🎯 **Current Configuration**

**As of Oct 13, 2025:**
- ✅ YubiKey-only authentication
- ❌ No Touch ID bypass
- ❌ No password fallback
- ✅ register-yubikey script installed
- ✅ Backup configs saved
- ✅ Documented in repo

**YubiKey stored:** With girlfriend (intentional friction to prevent bypass)

---

**For full system documentation, see:** `SCRIPTS_REFERENCE.md`  
**For installation on new Mac, see:** `FRESH_INSTALL_GUIDE.md`

