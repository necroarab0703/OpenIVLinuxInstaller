#!/bin/bash
# Build script for OpenIV Linux AppImage
# Requires: appimagetool (from AppImageKit)

set -e

APP_NAME="OpenIV"
ARCH="x86_64"
BUILD_DIR="Build/AppDir"
OUTPUT="${APP_NAME}-${ARCH}.AppImage"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR" "$OUTPUT"

echo "==> Creating AppDir structure..."
mkdir -p "$BUILD_DIR"

echo "==> Copying files..."
cp OpenIVScripts/OpenIVLinuxInstaller.sh "$BUILD_DIR/"
cp AppImage/AppRun "$BUILD_DIR/"
cp AppImage/openiv.desktop "$BUILD_DIR/"
cp AppImage/openiv.png "$BUILD_DIR/"

echo "==> Setting permissions..."
chmod +x "$BUILD_DIR/AppRun"
chmod +x "$BUILD_DIR/OpenIVLinuxInstaller.sh"

echo "==> Building AppImage..."
ARCH="$ARCH" appimagetool "$BUILD_DIR" "$OUTPUT"

echo ""
echo "==> Done! Created: $OUTPUT"
ls -lh "$OUTPUT"
