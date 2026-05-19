#!/bin/bash
################################################################################
# build-appimage.sh  –  OpenIV Linux AppImage Builder
#
# 1. Runs build-wine-prefix.sh to obtain a pre-baked prefix + portable Wine.
# 2. Assembles the AppDir with both Wine binaries and the prefix tarball.
# 3. Runs appimagetool to produce the final .AppImage.
#
# Usage:
#   ./build-appimage.sh
#
# Environment:
#   WINE_VERSION    – Kron4ek Wine version (default: 11.9)
#   WINE_FLAVOR     – Kron4ek flavour      (default: staging-amd64-wow64)
################################################################################
set -euo pipefail

APP_NAME="OpenIV"
ARCH="x86_64"
BUILD_DIR="$(pwd)/Build"
APP_DIR="$BUILD_DIR/AppDir"
OUTPUT="$BUILD_DIR/${APP_NAME}-${ARCH}.AppImage"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              OpenIV AppImage Builder                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1 – Build pre-baked prefix + fetch Wine ─────────────────────────────
echo "==> [1/4] Building pre-baked Wine prefix …"
echo "    (run build-wine-prefix.sh; this takes 10-25 minutes on first run)"
echo ""

bash OpenIVScripts/build-wine-prefix.sh

# ── Step 2 – Clean + create AppDir skeleton ──────────────────────────────────
echo "==> [2/4] Creating AppDir structure …"
rm -rf "$APP_DIR" "$OUTPUT"

mkdir -p "$APP_DIR/usr/share/openiv/wine"
mkdir -p "$APP_DIR/usr/share/applications"

# ── Step 3 – Populate AppDir ─────────────────────────────────────────────────
echo "==> [3/4] Populating AppDir …"

# Runtime installer
cp OpenIVScripts/OpenIVLinuxInstaller.sh "$APP_DIR/OpenIVLinuxInstaller.sh"
chmod +x "$APP_DIR/OpenIVLinuxInstaller.sh"

# AppRun
cp AppImage/AppRun "$APP_DIR/AppRun"
chmod +x "$APP_DIR/AppRun"

# Desktop entry + icon
cp AppImage/openiv.desktop "$APP_DIR/openiv.desktop"
cp AppImage/openiv.png "$APP_DIR/openiv.png"

# Pre-baked prefix tarball
cp build/prefix-builder/../prefix.tar.xz "$APP_DIR/usr/share/openiv/prefix.tar.xz"
echo "    Prefix tarball: $(du -h "$APP_DIR/usr/share/openiv/prefix.tar.xz" | cut -f1)"

# Portable Wine binaries
cp -a build/prefix-builder/wine/. "$APP_DIR/usr/share/openiv/wine/"
echo "    Wine binaries:  $(du -sh "$APP_DIR/usr/share/openiv/wine" | cut -f1)"

# ── Step 4 – Run appimagetool ────────────────────────────────────────────────
echo "==> [4/4] Running appimagetool …"
echo ""

if command -v appimagetool >/dev/null 2>&1; then
    ARCH="$ARCH" appimagetool "$APP_DIR" "$OUTPUT"
elif [ -f /tmp/appimagetool ]; then
    ARCH="$ARCH" /tmp/appimagetool --appimage-extract-and-run "$APP_DIR" "$OUTPUT" 2>/dev/null || \
    ARCH="$ARCH" /tmp/appimagetool "$APP_DIR" "$OUTPUT"
else
    echo "==> ERROR: appimagetool not found. Install from:"
    echo "    https://github.com/AppImage/AppImageKit/releases"
    echo "    Or place it at /tmp/appimagetool"
    exit 1
fi

echo ""
echo "==> Done! Created: $OUTPUT"
ls -lh "$OUTPUT"
echo ""
