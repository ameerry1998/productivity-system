# Display Lockdown PKG

A signed macOS installer package that turns the MacBook into a clamshell-only workstation. When installed:

- **External monitor connected:** internal MacBook display is disabled (kept dark even with lid open).
- **No external monitor connected:** Mac goes to sleep within 10 seconds.

This is a commitment device — the MacBook can only be used as a desk-bound computer with an external display. Designed to live alongside the rest of `productivity-system`.

## How it works

Two mutually-reviving root-owned LaunchDaemons running every 10 seconds:

1. **Primary daemon** — polls `displayplacer list` for external screens. If found: disables the internal display by its UUID. If not found: calls `pmset sleepnow`.
2. **Watchdog daemon** — checks the primary is loaded; reloads it if missing. The primary returns the favor.

Both daemons live in `/Library/LaunchDaemons/`, scripts in `/Library/Scripts/`, the `displayplacer` binary in `/usr/local/bin/`. All root-owned 644/755. Cannot be killed or unloaded by a standard user.

## Install

```bash
# Easiest: double-click the .pkg in Finder
open display-lockdown-2.0.pkg

# Or from terminal (requires admin auth via YubiKey/password)
sudo installer -pkg display-lockdown-2.0.pkg -target /
```

The PKG's postinstall script:
- Removes any previous version of the lockdown daemons
- Sets correct ownership (`root:wheel`) on all installed files
- Bootstraps both daemons via `launchctl bootstrap system`

Both daemons start within seconds. To confirm:

```bash
# Should see both labels listed
launchctl list | grep -v com.apple | head

# Tail the verbose logs
sudo tail -f /var/log/zerotier-networkservice.log /var/log/crashplan-proservice.log
```

## Uninstall (requires admin)

```bash
# Unload both daemons first (mutual revival means you must bootout both)
sudo launchctl bootout system/com.zerotier.networkservice
sudo launchctl bootout system/com.crashplan.proservice

# Remove files
sudo rm /Library/LaunchDaemons/com.zerotier.networkservice.plist
sudo rm /Library/LaunchDaemons/com.crashplan.proservice.plist
sudo rm /Library/Scripts/zerotier-networkservice.sh
sudo rm /Library/Scripts/crashplan-proservice.sh

# Optional: re-enable internal display immediately
displayplacer "id:37D8832A-2D66-02CA-B9F7-8F30A301B230 enabled:true"
```

## Configuration

The internal display UUID is hardcoded in `src/payload/Library/Scripts/zerotier-networkservice.sh` as `INTERNAL_UUID`. If the display panel is ever replaced (or you build this for a different Mac), update the UUID:

```bash
# Find your built-in display's persistent UUID
displayplacer list | grep -B 1 "Built-in"
```

Then edit `src/payload/Library/Scripts/zerotier-networkservice.sh`, change `INTERNAL_UUID`, and rebuild.

The poll interval (currently 10 seconds) is in both plist files as `<key>StartInterval</key><integer>10</integer>`. Tighten to 5 if you want a faster sleep response.

## Rebuilding the PKG

```bash
bash build-pkg.sh
```

Requires:
- macOS with Xcode CLT (for `pkgbuild` and `productsign`)
- `Developer ID Installer: Amer Raiyan (B7B67856A7)` cert in the login keychain

The build script outputs a signed PKG at `display-lockdown-2.0.pkg`.

## Recovery: locked out and need to disable

If your external monitor dies or you're stuck:

1. Power off the Mac
2. On Apple Silicon: hold the power button at boot to enter Startup Options
3. Authenticate as a volume owner (your password OR Caity's)
4. Choose Options → Continue → macOS Recovery → Utilities → Terminal
5. Mount the system volume and remove the daemon files:
   ```
   csrutil disable
   # reboot, hold power again to re-enter Recovery
   rm /Volumes/Macintosh\ HD/Library/LaunchDaemons/com.zerotier.networkservice.plist
   rm /Volumes/Macintosh\ HD/Library/LaunchDaemons/com.crashplan.proservice.plist
   csrutil enable
   ```
6. Reboot normally

This is the intentional escape hatch. Requires deliberate multi-step action.

## Files

```
lockdown-installer/
├── display-lockdown-2.0.pkg    # Signed installer (install this)
├── build-pkg.sh                # Rebuild the PKG from source
├── README.md
└── src/
    ├── payload/                # Files that get installed to / (root)
    │   ├── Library/
    │   │   ├── LaunchDaemons/
    │   │   │   ├── com.zerotier.networkservice.plist
    │   │   │   └── com.crashplan.proservice.plist
    │   │   └── Scripts/
    │   │       ├── zerotier-networkservice.sh
    │   │       └── crashplan-proservice.sh
    │   └── usr/local/bin/
    │       └── displayplacer        # The CLI tool, bundled for offline install
    └── scripts/
        └── postinstall              # Runs as root during PKG install
```
