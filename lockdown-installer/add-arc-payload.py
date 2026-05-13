#!/usr/bin/env python3
"""
Take a Tech Lockdown .mobileconfig (signed or unsigned) and add browser
payloads for browsers not covered by Tech Lockdown by default.

Adds these Chromium-based browsers (URLBlocklist mirrored from Chrome):
    - Arc
    - Vivaldi
    - Opera
    - Opera GX
    - Chromium
    - Sidekick
    - Wavebox

Adds this Firefox-based browser (WebsiteFilter mirrored from Firefox):
    - LibreWolf

Output is unsigned. Use regen-profile.sh to also sign.

Usage:
    python3 add-arc-payload.py <input.mobileconfig> <output.mobileconfig>
"""
import plistlib
import subprocess
import sys
import uuid


# Chromium browsers: get the same URLBlocklist payload as Chrome
CHROMIUM_BROWSERS = [
    ("Arc",         "company.thebrowser.Browser"),
    ("Vivaldi",     "com.vivaldi.Vivaldi"),
    ("Opera",       "com.operasoftware.Opera"),
    ("Opera GX",    "com.operasoftware.OperaGX"),
    ("Chromium",    "org.chromium.Chromium"),
    ("Sidekick",    "com.pushplaylabs.sidekick"),
    ("Wavebox",     "io.wavebox.app.macos"),
]

# Firefox-based browsers: get the same WebsiteFilter payload as Firefox
FIREFOX_BROWSERS = [
    ("LibreWolf",   "org.librewolf.librewolf"),
]


def load_profile(path):
    """Decode a signed or unsigned .mobileconfig into a dict."""
    result = subprocess.run(
        ["security", "cms", "-D", "-i", path],
        capture_output=True,
    )
    if result.returncode == 0 and result.stdout.lstrip().startswith(b"<?xml"):
        return plistlib.loads(result.stdout)
    with open(path, "rb") as f:
        return plistlib.load(f)


def build_chromium_payload(name, bundle_id, chrome_payload):
    """Construct a Chromium-style browser payload from Chrome's settings."""
    pl_uuid = str(uuid.uuid4()).upper()
    payload = {
        "PayloadDisplayName": name,
        "PayloadIdentifier": f"{bundle_id}.{pl_uuid.lower()}",
        "PayloadUUID": pl_uuid,
        "PayloadVersion": 1,
        "PayloadType": bundle_id,
        "URLBlocklist": list(chrome_payload.get("URLBlocklist", [])),
        "URLAllowlist": list(chrome_payload.get("URLAllowlist", [])),
        "SafeSitesFilterBehavior": chrome_payload.get("SafeSitesFilterBehavior", 1),
        # Hardening
        "DnsOverHttpsMode": "off",
        "BuiltInDnsClientEnabled": False,
        "QuicAllowed": False,
        "IncognitoModeAvailability": 1,
        "BrowserGuestModeEnabled": False,
        "DeveloperToolsAvailability": 2,
        "ExtensionInstallBlocklist": ["*"],
    }
    for key in [
        "CookiesBlockedForUrls",
        "CookiesAllowedForUrls",
        "ImagesBlockedForUrls",
        "ImagesAllowedForUrls",
        "JavaScriptBlockedForUrls",
        "JavaScriptAllowedForUrls",
    ]:
        if key in chrome_payload:
            payload[key] = list(chrome_payload[key])
    return payload


def build_firefox_payload(name, bundle_id, firefox_payload):
    """Construct a Firefox-style browser payload from Firefox's settings."""
    pl_uuid = str(uuid.uuid4()).upper()
    payload = {
        "PayloadDisplayName": name,
        "PayloadIdentifier": f"{bundle_id}.{pl_uuid.lower()}",
        "PayloadUUID": pl_uuid,
        "PayloadVersion": 1,
        "PayloadType": bundle_id,
    }
    # Copy all the Firefox-specific keys
    for key, value in firefox_payload.items():
        if key in ("PayloadDisplayName", "PayloadIdentifier", "PayloadUUID",
                   "PayloadVersion", "PayloadType"):
            continue
        # Deep copy lists/dicts to avoid sharing
        if isinstance(value, list):
            payload[key] = list(value)
        elif isinstance(value, dict):
            payload[key] = dict(value)
        else:
            payload[key] = value
    return payload


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)

    in_path, out_path = sys.argv[1], sys.argv[2]
    profile = load_profile(in_path)

    chrome_payload = None
    firefox_payload = None
    for p in profile.get("PayloadContent", []):
        if p.get("PayloadType") == "com.google.Chrome":
            chrome_payload = p
        elif p.get("PayloadType") == "org.mozilla.firefox":
            firefox_payload = p

    if chrome_payload is None:
        print("ERROR: no com.google.Chrome payload found in input.")
        sys.exit(1)

    bundle_ids_to_add = (
        [bid for _, bid in CHROMIUM_BROWSERS]
        + [bid for _, bid in FIREFOX_BROWSERS]
    )
    # Remove any existing payloads for these browsers (idempotent rerun)
    profile["PayloadContent"] = [
        p for p in profile["PayloadContent"]
        if p.get("PayloadType") not in bundle_ids_to_add
    ]

    added = []
    for name, bundle_id in CHROMIUM_BROWSERS:
        payload = build_chromium_payload(name, bundle_id, chrome_payload)
        profile["PayloadContent"].append(payload)
        added.append((name, bundle_id))

    if firefox_payload:
        for name, bundle_id in FIREFOX_BROWSERS:
            payload = build_firefox_payload(name, bundle_id, firefox_payload)
            profile["PayloadContent"].append(payload)
            added.append((name, bundle_id))
    else:
        print("WARN: no org.mozilla.firefox payload found; skipping LibreWolf.")

    # Update top-level identifier so macOS sees this as a distinct profile
    if not profile.get("PayloadIdentifier", "").endswith(".with-extra-browsers"):
        profile["PayloadIdentifier"] = (
            profile.get("PayloadIdentifier", "") + ".with-extra-browsers"
        )

    with open(out_path, "wb") as f:
        plistlib.dump(profile, f)

    blocklist_size = len(chrome_payload.get("URLBlocklist", []))
    print(f"✓ Wrote unified profile to: {out_path}")
    print(f"  URLBlocklist size (mirrored from Chrome): {blocklist_size}")
    print(f"  Added {len(added)} browser payloads:")
    for name, bid in added:
        print(f"    - {name:12} ({bid})")
    print()
    print("Install with: open " + repr(out_path))


if __name__ == "__main__":
    main()
