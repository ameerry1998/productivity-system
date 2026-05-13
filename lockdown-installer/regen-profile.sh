#!/bin/bash
# Take a Tech Lockdown-generated .mobileconfig, add an Arc browser payload,
# sign with the user's Developer ID Application cert, and output a single
# unified .mobileconfig ready to install.
#
# Usage:
#   bash regen-profile.sh <input.mobileconfig> [output.mobileconfig]
#
# If no output path is provided, defaults to ~/Downloads/ameer.rayan-with-arc.mobileconfig

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SIGNING_IDENTITY="Developer ID Application: Amer Raiyan (B7B67856A7)"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <input.mobileconfig> [output.mobileconfig]"
    echo ""
    echo "Default output: ~/Downloads/ameer.rayan-with-arc.mobileconfig"
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-$HOME/Downloads/ameer.rayan-with-arc.mobileconfig}"
TMP_UNSIGNED="$(mktemp -t mobileconfig-unsigned).plist"

# Step 1: add Arc payload (produces unsigned XML mobileconfig)
echo "→ Adding Arc payload..."
python3 "$SCRIPT_DIR/add-arc-payload.py" "$INPUT" "$TMP_UNSIGNED"

# Step 2: sign with Developer ID Application cert
echo "→ Signing with $SIGNING_IDENTITY..."
security cms -S -N "$SIGNING_IDENTITY" -i "$TMP_UNSIGNED" -o "$OUTPUT"

# Clean up
rm -f "$TMP_UNSIGNED"

echo ""
echo "✓ Done. Signed unified profile:"
echo "  $OUTPUT"
echo ""
echo "Install with:"
echo "  open \"$OUTPUT\""
