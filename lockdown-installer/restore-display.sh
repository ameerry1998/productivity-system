#!/bin/bash
# Restore the previously-saved permanent display configuration via CoreGraphics.
# This re-activates an internal display that was disabled by displayplacer
# (or any other tool that called CGSConfigureDisplayMode with disabled state).
#
# Confirmed working 2026-05-14 without reboot, sleep, or unplugging anything.

set -euo pipefail

swift -e 'import CoreGraphics; CGRestorePermanentDisplayConfiguration()' 2>&1

echo "✓ Called CGRestorePermanentDisplayConfiguration()."
echo "  Internal display should be back within ~1 second."
echo "  If not, try: open lid, or unplug+replug external monitor."
