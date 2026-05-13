#!/bin/bash
# Build and sign the display lockdown PKG from source.
# Run as: bash build-pkg.sh
# No sudo required to build (just to install the resulting PKG).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
BUILD_DIR="$SCRIPT_DIR/.build"
VERSION="2.0"
OUTPUT_PKG="$SCRIPT_DIR/display-lockdown-${VERSION}.pkg"
SIGNING_IDENTITY="Developer ID Installer: Amer Raiyan (B7B67856A7)"
IDENTIFIER="com.arayan.displaylockdown"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Building unsigned PKG..."
pkgbuild \
    --root "$SRC_DIR/payload" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --scripts "$SRC_DIR/scripts" \
    --install-location / \
    "$BUILD_DIR/unsigned.pkg"

echo "Signing PKG with $SIGNING_IDENTITY..."
productsign \
    --sign "$SIGNING_IDENTITY" \
    "$BUILD_DIR/unsigned.pkg" \
    "$OUTPUT_PKG"

echo ""
echo "✓ PKG built: $OUTPUT_PKG"
pkgutil --check-signature "$OUTPUT_PKG" | head -5
