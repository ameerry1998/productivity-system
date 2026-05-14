# Display Lockdown Recovery

How to undo the display lockdown without rebooting.

## TL;DR

1. **Disable the daemons** by installing `display-lockdown-off-1.0.pkg` (the teardown PKG).
2. **Restore the internal display** by running:
   ```bash
   swift -e 'import CoreGraphics; CGRestorePermanentDisplayConfiguration()'
   ```

That's it. Tested 2026-05-14 — internal screen reactivated without reboot.

---

## The problem we ran into

When the daemon ran `displayplacer "id:<UUID> enabled:false"`, the internal display went away from `displayplacer list`, `system_profiler SPDisplaysDataType`, and even `ioreg -c IOMobileFramebuffer`. The display was disconnected at the IOKit framebuffer level — not merely hidden from WindowServer.

Running the obvious reverse:
```bash
displayplacer "id:<UUID> enabled:true"
```
fails with `Unable to find screen` because displayplacer can only act on displays the system currently enumerates. Disabled-at-framebuffer = not enumerated = not actionable.

## Why CGRestorePermanentDisplayConfiguration() works

`CGRestorePermanentDisplayConfiguration()` is a CoreGraphics API documented for restoring the **previously saved permanent display configuration**. When apps like displayplacer change display state, macOS keeps a "permanent" reference configuration that this call resets to.

Calling it forces WindowServer (and the framebuffer subsystem underneath) to re-evaluate all attached displays and apply the permanent configuration — which includes the internal display as enabled.

This is different from sleep/wake or a reboot because it's a direct API call into the live WindowServer state — no display power cycling needed.

## Tools that failed and why

| Tool | Why it failed |
|---|---|
| `displayplacer "id:<UUID> enabled:true"` | Internal display not enumerated, so target is unreachable. |
| `displayplacer list` | Only sees enumerated displays. Internal was framebuffer-disconnected. |
| `system_profiler SPDisplaysDataType` | Same — only enumerates currently-active displays. |
| `ioreg -c IOMobileFramebuffer` | The internal display's framebuffer wasn't registered. |
| `pmset displaysleepnow` | Sleeps the active display(s) but doesn't trigger reconfig. |
| `betterdisplaycli get` | BetterDisplay's host app wasn't running; CLI is just an RPC client. |

## Tools that work

| Tool | Notes |
|---|---|
| `CGRestorePermanentDisplayConfiguration()` (CoreGraphics) | ✅ Reactivates the internal display without reboot. **Confirmed working.** |
| Reboot | Always works. Display state always fully resets at boot. |
| Sleep / wake cycle | Sometimes works depending on configuration. |
| Unplug + replug external monitor | Often works — display reconfig event triggers re-enumeration. |
| `sudo killall WindowServer` | Works but logs you out and closes all apps. Heavy. |

## One-liner you can save as a shell alias

```bash
alias restore-display='swift -e "import CoreGraphics; CGRestorePermanentDisplayConfiguration()"'
```

Then just type `restore-display` whenever the internal screen is stuck off after the lockdown daemons disabled it.

A standalone helper script is also at `restore-display.sh` in this directory.
