#!/bin/bash
################################################################################
# OpenIV Linux Launcher  –  Self-Contained Portable AppImage
#
# This script is designed to run from inside a pre-bundled AppImage.  All
# assets (Wine-GE, pre-baked prefix with .NET 4.8 + DXVK 2.4, New Technology
# Studio pre-installed) are baked into the AppDir at build time.  Nothing is
# downloaded at runtime.
#
# When executed standalone (no $APPDIR), the script errors immediately and
# directs the user to use the AppImage.
#
# Usage (AppImage only):
#   chmod +x OpenIV-x86_64.AppImage
#   ./OpenIV-x86_64.AppImage
################################################################################
set -euo pipefail

# ── Shell / Self-Exec Guard ───────────────────────────────────────────────────
if [ -z "${BASH_VERSION:-}" ]; then
    command -v bash >/dev/null 2>&1 && exec bash "$0" "$@"
    echo "This script requires bash" >&2; exit 1
fi

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPDIR="${APPDIR:-}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

DATA_DIR="$XDG_DATA_HOME/openiv-linux"
PREFIX_DIR="$DATA_DIR/prefix"

# Bundled resource paths (inside the AppImage)
BUNDLED_WINE_DIR="$APPDIR/usr/share/openiv/wine"
BUNDLED_PREFIX_TARBALL="$APPDIR/usr/share/openiv/prefix-core.tar.xz"

# Resolved at runtime
WINE_DIR=""
WINE_BINARY=""
OPENIV_EXE=""

# ── Terminal Colours ───────────────────────────────────────────────────────────
if [ -t 1 ]; then
    RED='\033[0;31m';    GREEN='\033[0;32m';   YELLOW='\033[1;33m'
    BLUE='\033[0;34m';   CYAN='\033[0;36m';    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi
log_header() { echo -e "${CYAN}━━━ $* ━━━${NC}"; }
log_step()   { echo -e "  ${BLUE}•${NC} $*"; }
log_ok()     { echo -e "  ${GREEN}✓${NC} $*"; }
log_warn()   { echo -e "  ${YELLOW}⚠${NC} $*"; }
log_err()    { echo -e "  ${RED}✗${NC} $*" >&2; }

# ── 1.  Guard: AppImage mode only ─────────────────────────────────────────────
guard_appimage_mode() {
    if [ -z "$APPDIR" ]; then
        log_err "This script is designed to run only inside the OpenIV AppImage."
        log_err ""
        log_err "  ${BOLD}Download the AppImage from:${NC}"
        log_err "  https://github.com/necroarab0703/OpenIVLinuxInstaller/releases"
        log_err ""
        log_err "  ${BOLD}Then run:${NC}"
        log_err "  chmod +x OpenIV-x86_64.AppImage"
        log_err "  ./OpenIV-x86_64.AppImage"
        exit 0
    fi
}

# ── 2.  Directory Setup ───────────────────────────────────────────────────────
setup_directories() {
    mkdir -p "$PREFIX_DIR"
}

# ── 3.  Wine Runtime (from AppImage bundle) ───────────────────────────────────
ensure_wine() {
    log_header "Wine Runtime"

    if [ ! -x "$BUNDLED_WINE_DIR/bin/wine" ]; then
        log_err "Bundled Wine not found at $BUNDLED_WINE_DIR/bin/wine"
        log_err "The AppImage may be corrupted. Please re-download."
        exit 2
    fi

    WINE_DIR="$BUNDLED_WINE_DIR"
    WINE_BINARY="$WINE_DIR/bin/wine"
    local ver; ver=$("$WINE_BINARY" --version 2>/dev/null || echo "bundled")
    log_ok "Wine $ver (bundled)"
}

# ── 4.  Wine Prefix (extract pre-baked tarball) ───────────────────────────────
ensure_prefix() {
    log_header "Wine Prefix"

    if [ -f "$PREFIX_DIR/drive_c/windows/system32/kernel32.dll" ]; then
        log_ok "Prefix already exists at $PREFIX_DIR"
        return 0
    fi

    if [ ! -f "$BUNDLED_PREFIX_TARBALL" ]; then
        log_err "Pre-baked prefix tarball not found at $BUNDLED_PREFIX_TARBALL"
        exit 3
    fi

    log_step "Extracting pre-baked prefix (with .NET 4.8 pre-installed) …"
    mkdir -p "$PREFIX_DIR"
    tar -xJf "$BUNDLED_PREFIX_TARBALL" -C "$PREFIX_DIR" 2>/dev/null || {
        log_err "Prefix tarball extraction failed"
        exit 3
    }

    if [ ! -f "$PREFIX_DIR/drive_c/windows/system32/kernel32.dll" ]; then
        log_err "Extraction produced an incomplete prefix"
        exit 3
    fi

    log_ok "Prefix extracted ($(du -sh "$PREFIX_DIR" | cut -f1))"
}

# ── 5.  Dynamic session mapping ──────────────────────────────────────────────
map_cloud_profile() {
    CLOUD_USER_PATH="$PREFIX_DIR/drive_c/users/runner/AppData/Local/New Technology Studio"
    LOCAL_USER_PATH="$PREFIX_DIR/drive_c/users/$USER/AppData/Local"
    if [ -d "$CLOUD_USER_PATH" ]; then
        log_step "Mapping cloud profile assets to local session ($USER) …"
        mkdir -p "$LOCAL_USER_PATH"
        mv "$CLOUD_USER_PATH" "$LOCAL_USER_PATH/"
        log_ok "Profile mapped successfully."
    fi
}

# ── 6.  Verification ──────────────────────────────────────────────────────────
verify_installation() {
    log_header "Verification"

    local target="$PREFIX_DIR/drive_c/users/$USER/AppData/Local/New Technology Studio/Apps/OpenIV/OpenIV.exe"
    if [ -f "$target" ]; then
        OPENIV_EXE="$target"
        log_ok "OpenIV executable found: $target"
        return 0
    fi

    local found
    found=$(find "$PREFIX_DIR/drive_c" -maxdepth 6 -name "OpenIV.exe" -type f 2>/dev/null | head -1 || true)
    if [ -n "$found" ]; then
        OPENIV_EXE="$found"
        log_ok "OpenIV executable found: $found"
        return 0
    fi

    log_warn "OpenIV executable not found in the pre-installed prefix."
    return 1
}

# ── 7.  Launcher Script & Desktop Entry ───────────────────────────────────────
create_launchers() {
    log_header "Desktop Integration"

    local desktop_dir="${XDG_DATA_HOME}/applications"
    local icons_dir="${XDG_DATA_HOME}/icons"
    mkdir -p "$desktop_dir" "$icons_dir"

    local icon_path="$icons_dir/openiv.png"
    local desktop_file="$desktop_dir/openiv.desktop"
    local wrapper_script="$DATA_DIR/openiv.sh"

    # Icon
    if [ -f "$APPDIR/openiv.png" ]; then
        cp "$APPDIR/openiv.png" "$icon_path"
    elif [ ! -f "$icon_path" ]; then
        printf '\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\000\001\000\000\000\001\010\002\000\000\000\220wS\336\000\000\000\022IDATx\234c\370\017\000\000\001\001\001\002\370\217\374\351\000\000\000\000IEND\246B`\202' > "$icon_path"
    fi

    # Wrapper – uses the bundled high-compatibility Wine-GE runtime
    cat > "$wrapper_script" << WRAPEOF
#!/bin/bash
# OpenIV launcher – generated by OpenIVLinuxInstaller
export WINEPREFIX="$PREFIX_DIR"
export WINEARCH="win32"
export WINEDEBUG="${WINEDEBUG:--all}"
export WINEDLLOVERRIDES="d3d11,dxgi=n"
export PATH="$WINE_DIR/bin:\$PATH"
exec "$WINE_BINARY" "\$@"
WRAPEOF
    chmod +x "$wrapper_script"

    cat > "$desktop_file" << DESKTOPEOF
[Desktop Entry]
Name=OpenIV
Comment=The ultimate modding tool for GTA V, GTA IV and Max Payne 3
Exec=$wrapper_script
Icon=$icon_path
Terminal=false
Type=Application
Categories=Game;Utility;
StartupWMClass=openiv.exe
StartupNotify=true
DESKTOPEOF

    log_ok "Desktop entry: $desktop_file"
    log_ok "Launcher script: $wrapper_script"

    # Shell alias
    local shell_rc=""
    [ -f "$HOME/.bashrc" ] && shell_rc="$HOME/.bashrc"
    [ -z "$shell_rc" ] && [ -f "$HOME/.zshrc" ] && shell_rc="$HOME/.zshrc"
    if [ -n "$shell_rc" ] && ! grep -q "alias openiv=" "$shell_rc" 2>/dev/null; then
        { echo ""; echo "# OpenIV launcher (portable Wine)"; echo "alias openiv='$wrapper_script'"; } >> "$shell_rc"
        log_ok "Added 'openiv' alias to $shell_rc"
    fi
}

# ── 8.  Summary ───────────────────────────────────────────────────────────────
print_summary() {
    echo ""; log_header "Launch Ready"; echo ""
    echo -e "  ${GREEN}OpenIV is pre-installed and ready to launch.${NC}"
    echo ""
    echo -e "  ${BOLD}Launch methods:${NC}"
    echo -e "    ${GREEN}1.${NC} Terminal: ${CYAN}openiv${NC}"
    echo -e "    ${GREEN}2.${NC} Application menu: ${CYAN}OpenIV${NC}"
    echo ""
    echo -e "  ${BOLD}Uninstall:${NC}  ${CYAN}rm -rf \"$DATA_DIR\"${NC}"
    echo -e "  ${BOLD}Prefix:${NC}     ${CYAN}$PREFIX_DIR${NC}"
    echo ""
}

launch_openiv() {
    [ -n "$OPENIV_EXE" ] && [ -f "$OPENIV_EXE" ] || { log_warn "OpenIV unavailable — skipping launch."; return; }
    export WINEPREFIX="$PREFIX_DIR" WINEARCH="win32" WINEDEBUG="${WINEDEBUG:--all}" WINEDLLOVERRIDES="d3d11,dxgi=n"
    PATH="$WINE_DIR/bin:$PATH"
    exec "$WINE_BINARY" "$OPENIV_EXE"
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║${NC}          ${BOLD}OpenIV Linux Launcher v7${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}          ${GREEN}[Self-contained – DXVK 2.4 + Wine-GE]${NC}                ${CYAN}║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    guard_appimage_mode
    setup_directories
    ensure_wine
    ensure_prefix
    map_cloud_profile

    if verify_installation; then
        create_launchers
        print_summary
        launch_openiv
    else
        log_warn "OpenIV executable not found in the pre-installed prefix."
        log_warn "Check $PREFIX_DIR/drive_c/users/ manually."
        exit 5
    fi
}

main "$@"
