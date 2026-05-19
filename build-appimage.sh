#!/bin/bash
set -euo pipefail

APP_NAME="OpenIV"
ARCH="x86_64"
BUILD_DIR="$(pwd)/build"
APP_DIR="$BUILD_DIR/openiv-installer.AppDir"
OUTPUT="$BUILD_DIR/${APP_NAME}-${ARCH}.AppImage"

# Locate OpenIVSetup.exe — check project root first, then common locations
OPENIV_SETUP="${OPENIV_SETUP:-}"
if [ -z "$OPENIV_SETUP" ]; then
    for candidate in \
        "$(pwd)/OpenIVSetup.exe" \
        "/home/necroarab/Projects/OpenIV-Wine/OpenIVSetup.exe" \
        "/tmp/OpenIVSetup.exe"; do
        if [ -f "$candidate" ]; then
            OPENIV_SETUP="$candidate"
            break
        fi
    done
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              OpenIV AppImage Builder v4                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ── Step 1 – Build pre-baked prefix + fetch Wine ─────────────────────────────
echo "==> [1/5] Building pre-baked Wine prefix …"
echo "    (run build-wine-prefix.sh; this takes 10-25 minutes on first run)"
echo ""

bash OpenIVScripts/build-wine-prefix.sh

# ── Step 2 – Verify local OpenIVSetup.exe ─────────────────────────────────────
echo "==> [2/5] Verifying local OpenIVSetup.exe …"

if [ -z "$OPENIV_SETUP" ] || [ ! -f "$OPENIV_SETUP" ]; then
    echo "==> ERROR: OpenIVSetup.exe not found."
    echo "    Place it in the project root as ./OpenIVSetup.exe"
    echo "    or set OPENIV_SETUP=/path/to/OpenIVSetup.exe"
    echo "    or use one of the default search paths."
    exit 1
fi

INSTALLER_SIZE=$(du -h "$OPENIV_SETUP" | cut -f1)
echo "    Found: $OPENIV_SETUP ($INSTALLER_SIZE)"

# ── Step 3 – Clean + create AppDir skeleton ──────────────────────────────────
echo "==> [3/5] Creating AppDir structure …"
rm -rf "$APP_DIR" "$OUTPUT"

mkdir -p "$APP_DIR/usr/share/openiv/wine"
mkdir -p "$APP_DIR/usr/share/applications"

# ── Step 4 – Populate AppDir ─────────────────────────────────────────────────
echo "==> [4/5] Populating AppDir …"

# Runtime installer (no longer used at runtime in v4, kept for reference)
cp OpenIVScripts/OpenIVLinuxInstaller.sh "$APP_DIR/OpenIVLinuxInstaller.sh"
chmod +x "$APP_DIR/OpenIVLinuxInstaller.sh"

# AppRun
cp AppImage/AppRun "$APP_DIR/AppRun"
chmod +x "$APP_DIR/AppRun"

# Desktop entry + icon
cp AppImage/openiv.desktop "$APP_DIR/openiv.desktop"
cp AppImage/openiv.png "$APP_DIR/openiv.png"

# Local OpenIVSetup.exe
cp "$OPENIV_SETUP" "$APP_DIR/usr/share/openiv/OpenIVSetup.exe"
echo "    OpenIVSetup.exe: $INSTALLER_SIZE"

# Pre-baked prefix tarball
PREFIX_TARBALL="$BUILD_DIR/prefix.tar.xz"
if [ ! -f "$PREFIX_TARBALL" ]; then
    echo "==> ERROR: Pre-baked prefix tarball not found at $PREFIX_TARBALL"
    echo "    build-wine-prefix.sh should have created it."
    exit 1
fi
cp "$PREFIX_TARBALL" "$APP_DIR/usr/share/openiv/prefix.tar.xz"
echo "    Prefix tarball: $(du -h "$APP_DIR/usr/share/openiv/prefix.tar.xz" | cut -f1)"

# Portable Wine binaries
WINE_SRC="$BUILD_DIR/prefix-builder/wine"
if [ ! -d "$WINE_SRC" ]; then
    echo "==> ERROR: Wine binaries not found at $WINE_SRC"
    echo "    build-wine-prefix.sh should have extracted them."
    exit 1
fi
cp -a "$WINE_SRC/." "$APP_DIR/usr/share/openiv/wine/"
echo "    Wine binaries:  $(du -sh "$APP_DIR/usr/share/openiv/wine" | cut -f1)"

# ── Step 5 – Run appimagetool ────────────────────────────────────────────────
echo "==> [5/5] Running appimagetool …"
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
