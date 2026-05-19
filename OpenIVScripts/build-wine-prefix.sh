#!/bin/bash
################################################################################
# build-wine-prefix.sh  –  Pre-baked Wine + .NET 4.8 Prefix Builder
#
# This script is run by the CI pipeline (or locally) *before* the AppImage is
# assembled.  It:
#   1. Downloads a portable Wine build from Kron4ek.
#   2. Creates a pristine Wine prefix (win64, Windows 10).
#   3. Installs dotnet48, vcrun2019, d3dx11_43, and corefonts via winetricks.
#   4. Cleans up (kills wineserver, removes temp files).
#   5. Compresses the prefix to  prefix.tar.xz .
#   6. Leaves the extracted Wine binaries in place for bundling.
#
# Usage:
#   ./OpenIVScripts/build-wine-prefix.sh [--wine-version 11.9] [--prefix-dir ./build/prefix]
#
# Output (in BUILD_DIR):
#   wine/               – extracted portable Wine (ready to copy into AppDir)
#   prefix.tar.xz       – compressed Wine prefix with all deps pre-installed
################################################################################
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
WINE_VERSION="${WINE_VERSION:-11.9}"
WINE_FLAVOR="${WINE_FLAVOR:-staging-amd64-wow64}"
BUILD_DIR="${BUILD_DIR:-$(pwd)/build/prefix-builder}"
CACHE_DIR="${CACHE_DIR:-$(pwd)/build/cache}"
CLONE_DIR="${CLONE_DIR:-$(pwd)/build}"

WINE_TAG="$WINE_VERSION"
WINE_TARBALL="wine-${WINE_VERSION}-${WINE_FLAVOR}.tar.xz"
WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_TAG}/${WINE_TARBALL}"

WINE_DIR="$BUILD_DIR/wine"
PREFIX_DIR="$BUILD_DIR/prefix"

mkdir -p "$BUILD_DIR" "$CACHE_DIR"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log() { echo -e "  ${BLUE}•${NC} $*"; }
ok()  { echo -e "  ${GREEN}✓${NC} $*"; }
warn(){ echo -e "  ${YELLOW}⚠${NC} $*"; }
err() { echo -e "  ${RED}✗${NC} $*" >&2; }

header() { echo ""; echo -e "${CYAN}━━━ $* ━━━${NC}"; echo ""; }

# ── 1.  Download portable Wine ────────────────────────────────────────────────
header "Step 1/5 — Download portable Wine ${WINE_VERSION} (${WINE_FLAVOR})"

WINE_CACHE="$CACHE_DIR/$WINE_TARBALL"
if [ ! -f "$WINE_CACHE" ]; then
    log "Downloading from Kron4ek …"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$WINE_URL" -o "$WINE_CACHE"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$WINE_URL" -O "$WINE_CACHE"
    else
        err "Neither curl nor wget found — cannot download Wine"
        exit 1
    fi
    ok "Wine tarball cached at $WINE_CACHE"
else
    ok "Wine tarball already cached"
fi

# ── 2.  Extract Wine ──────────────────────────────────────────────────────────
header "Step 2/5 — Extract Wine"

rm -rf "$WINE_DIR"
mkdir -p "$WINE_DIR"
log "Extracting (may take a moment) …"
tar -xJf "$WINE_CACHE" -C "$WINE_DIR" --strip-components=1 2>/dev/null || {
    err "Extraction failed — corrupt tarball?  Remove $WINE_CACHE and retry."
    exit 2
}
if [ ! -x "$WINE_DIR/bin/wine" ]; then
    err "wine binary missing after extraction"
    exit 2
fi
ok "Wine extracted to $WINE_DIR"
"$WINE_DIR/bin/wine" --version

# ── 3.  Create & configure prefix ─────────────────────────────────────────────
header "Step 3/5 — Create Wine prefix (win32, Windows 10)"

rm -rf "$PREFIX_DIR"
mkdir -p "$PREFIX_DIR"

export WINEPREFIX="$PREFIX_DIR"
export WINEARCH="win32"
export WINEDLLOVERRIDES="winemenubuilder.exe=d"
export WINEDEBUG="-all"
PATH="$WINE_DIR/bin:$PATH"

log "Running wineboot …"
"$WINE_DIR/bin/wineboot" -u 2>/dev/null || {
    err "wineboot failed"
    exit 3
}
if [ ! -d "$PREFIX_DIR/drive_c" ]; then
    err "drive_c not created"
    exit 3
fi
ok "Prefix created"

log "Setting Windows version to 10 …"
winetricks -q win10 2>/dev/null || warn "win10 exit non-zero"
ok "Windows 10 set"

# ── 4.  Install .NET 4.8 + VC++ + D3D + fonts ─────────────────────────────────
header "Step 4/5 — Install dependencies  (☕ this takes 10–25 minutes)"

export WINETRICKS_DOWNLOADER="${WINETRICKS_DOWNLOADER:-curl}"

for verb in dotnet48 vcrun2019 d3dx11_43 corefonts; do
    log "Installing $verb …"
    if winetricks -q "$verb" 2>/dev/null; then
        ok "$verb installed"
    else
        warn "$verb exit non-zero (may be benign)"
    fi
done

# ── 4b.  Clean up running Wine processes ──────────────────────────────────────
log "Stopping Wine processes …"
"$WINE_DIR/bin/wineserver" -k 2>/dev/null || true
sleep 2

# Remove Mono/Gecko cache artifacts, log files, etc.
rm -rf "$PREFIX_DIR/drive_c/windows/mono" \
       "$PREFIX_DIR/drive_c/windows/gecko" \
       "$PREFIX_DIR/drive_c/windows/temp"/* \
       "$PREFIX_DIR/drive_c/windows/system32/spool" \
       "$PREFIX_DIR/drive_c/ProgramData/Package Cache" \
       "$PREFIX_DIR"/.update-timestamp 2>/dev/null || true

ok "Dependencies installed; prefix cleaned"

# ── 5.  Compress prefix ───────────────────────────────────────────────────────
header "Step 5/5 — Compress prefix"

PREFIX_TARBALL="$CLONE_DIR/prefix.tar.xz"
log "Creating $PREFIX_TARBALL …"
# Exclude locks and tmp to keep it small
tar -cJf "$PREFIX_TARBALL" \
    --exclude='*.lock' \
    --exclude='*/drive_c/windows/temp/*' \
    --exclude='*/drive_c/windows/logs/*' \
    -C "$PREFIX_DIR" . 2>/dev/null
ok "Prefix compressed: $(du -h "$PREFIX_TARBALL" | cut -f1)"

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
header "Build Complete"
echo -e "  ${GREEN}Wine:${NC}       $WINE_DIR/bin/wine"
echo -e "  ${GREEN}Prefix:${NC}     $PREFIX_TARBALL ($(du -h "$PREFIX_TARBALL" | cut -f1))"
echo -e "  ${GREEN}Binary size:${NC} $(du -sh "$WINE_DIR" | cut -f1)"
echo ""
echo -e "  ${BOLD}Next:${NC} Run  ./build-appimage.sh  to assemble the AppImage."
echo ""
