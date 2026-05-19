#!/bin/bash
set -euo pipefail

APP_NAME="OpenIV"
ARCH="x86_64"
BUILD_DIR="$(pwd)/build"
APP_DIR="$BUILD_DIR/openiv-installer.AppDir"
OUTPUT="$BUILD_DIR/${APP_NAME}-${ARCH}.AppImage"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              OpenIV AppImage Builder v5                     ║"
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

# Local OpenIVSetup.exe — checks project root first, then common locations
OPENIV_SETUP="${OPENIV_SETUP:-}"
if [ -z "$OPENIV_SETUP" ]; then
    for candidate in "$(pwd)/OpenIVSetup.exe" "/tmp/OpenIVSetup.exe"; do
        if [ -f "$candidate" ]; then
            OPENIV_SETUP="$candidate"
            break
        fi
    done
fi
if [ -n "$OPENIV_SETUP" ] && [ -f "$OPENIV_SETUP" ]; then
    cp "$OPENIV_SETUP" "$APP_DIR/usr/share/openiv/OpenIVSetup.exe"
    echo "    OpenIVSetup.exe: $(du -h "$OPENIV_SETUP" | cut -f1)"
else
    echo "    OpenIVSetup.exe: not found (will be downloaded by CI at build time)"
fi

# Bundled fonts
FONTS_DIR="$APP_DIR/usr/share/openiv/fonts"
mkdir -p "$FONTS_DIR"
for font in arial.ttf tahoma.ttf; do
    if [ -f "/usr/share/fonts/truetype/msttcorefonts/$font" ]; then
        cp "/usr/share/fonts/truetype/msttcorefonts/$font" "$FONTS_DIR/"
    elif [ -f "/usr/share/fonts/truetype/liberation/${font/ttf/otf}" ]; then
        cp "/usr/share/fonts/truetype/liberation/${font/ttf/otf}" "$FONTS_DIR/"
    fi
done
echo "    Fonts: $(ls "$FONTS_DIR" 2>/dev/null | wc -l) files"

# Portable Wine binaries
WINE_SRC="$BUILD_DIR/prefix-builder/wine"
if [ ! -d "$WINE_SRC" ]; then
    echo "==> ERROR: Wine binaries not found at $WINE_SRC"
    echo "    build-wine-prefix.sh should have extracted them."
    exit 1
fi
cp -a "$WINE_SRC/." "$APP_DIR/usr/share/openiv/wine/"
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
