#!/bin/bash
set -euo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
    command -v bash >/dev/null 2>&1 && exec bash "$0" "$@"
    echo "This script requires bash" >&2; exit 1
fi

APPDIR="${APPDIR:-}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA_DIR="$XDG_DATA_HOME/openiv-linux"
PREFIX_DIR="$DATA_DIR/prefix"
LAUNCHER_SCRIPT="$DATA_DIR/openiv.sh"
BIN_DIR="$DATA_DIR/bin"

BUNDLED_WINE="$APPDIR/usr/share/openiv/wine"
BUNDLED_INSTALLER="$APPDIR/usr/share/openiv/OpenIVSetup.exe"
WINE_BINARY="$BUNDLED_WINE/bin/wine"
WINE_SERVER="$BUNDLED_WINE/bin/wineserver"

WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
WINETRICKS_BIN="$BIN_DIR/winetricks"

OPENIV_EXE=""

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

ensure_winetricks() {
    if command -v winetricks >/dev/null 2>&1; then
        WINETRICKS_BIN="$(command -v winetricks)"
        return 0
    fi
    if [ -x "$WINETRICKS_BIN" ]; then
        return 0
    fi
    log_step "Downloading winetricks …"
    mkdir -p "$BIN_DIR"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$WINETRICKS_URL" -o "$WINETRICKS_BIN" 2>/dev/null || {
            log_err "Failed to download winetricks"
            exit 2
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$WINETRICKS_URL" -O "$WINETRICKS_BIN" 2>/dev/null || {
            log_err "Failed to download winetricks"
            exit 2
        }
    else
        log_err "Neither curl nor wget found — cannot download winetricks"
        exit 2
    fi
    chmod +x "$WINETRICKS_BIN"
    log_ok "winetricks ready"
}

ensure_prefix() {
    log_header "Wine Prefix"

    if [ -f "$PREFIX_DIR/drive_c/windows/system32/kernel32.dll" ]; then
        log_ok "Prefix already exists at $PREFIX_DIR"
        return 0
    fi

    export WINEPREFIX="$PREFIX_DIR"
    export WINEARCH="win32"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    export WINEDEBUG="${WINEDEBUG:--all}"

    "$WINE_SERVER" -k 2>/dev/null || true

    log_step "Initialising Wine prefix (win32) …"
    mkdir -p "$PREFIX_DIR"
    "$WINE_BINARY" wineboot -u 2>/dev/null || { log_err "wineboot failed"; exit 3; }
    if [ ! -d "$PREFIX_DIR/drive_c" ]; then log_err "drive_c not created"; exit 3; fi
    log_ok "Prefix created"

    log_step "Injecting system interface fonts …"
    mkdir -p "$PREFIX_DIR/drive_c/windows/Fonts"
    if [ -n "$APPDIR" ] && [ -d "$APPDIR/usr/share/openiv/fonts" ]; then
        cp "$APPDIR/usr/share/openiv/fonts/"*.ttf "$PREFIX_DIR/drive_c/windows/Fonts/" 2>/dev/null
        log_ok "Fonts injected"
    fi

    ensure_winetricks

    log_step "Setting Windows 10 …"
    "$WINETRICKS_BIN" -q win10 2>/dev/null || log_warn "win10 exit non-zero"

    log_step "Installing .NET Framework 4.8 (this may take 10-20 minutes) …"
    "$WINETRICKS_BIN" -q dotnet48 2>/dev/null || log_warn "dotnet48 exit non-zero (may be benign)"

    log_step "Installing VC++ 2019 …"
    "$WINETRICKS_BIN" -q vcrun2019 2>/dev/null || log_warn "vcrun2019 exit non-zero"

    log_step "Installing DirectX 11.43 …"
    "$WINETRICKS_BIN" -q d3dx11_43 2>/dev/null || log_warn "d3dx11_43 exit non-zero"

    log_step "Installing corefonts …"
    "$WINETRICKS_BIN" -q corefonts 2>/dev/null || log_warn "corefonts exit non-zero"

    "$WINE_SERVER" -k 2>/dev/null || true
    log_ok "Prefix built from scratch"
}

install_openiv_silent() {
    log_header "Installing OpenIV"

    if [ -f "$PREFIX_DIR/drive_c/Program Files/OpenIV/OpenIV.exe" ] || \
       [ -f "$PREFIX_DIR/drive_c/Program Files (x86)/OpenIV/OpenIV.exe" ]; then
        log_ok "OpenIV already installed"
        return 0
    fi

    export WINEPREFIX="$PREFIX_DIR"
    export WINEARCH="win32"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    export WINEDEBUG="${WINEDEBUG:--all}"

    if [ -z "$APPDIR" ] || [ ! -f "$BUNDLED_INSTALLER" ]; then
        log_err "OpenIVSetup.exe not found at $BUNDLED_INSTALLER"
        log_err "OpenIV Linux Installer must run from within the AppImage."
        exit 4
    fi

    log_step "Running installer (interactive) …"
    "$WINE_BINARY" "$BUNDLED_INSTALLER" 2>/dev/null || log_warn "Installer exited"

    "$WINE_SERVER" -k 2>/dev/null || true
    log_ok "Installation phase complete"
}

verify_installation() {
    log_header "Verification"

    local paths=(
        "$PREFIX_DIR/drive_c/Program Files/OpenIV/OpenIV.exe"
        "$PREFIX_DIR/drive_c/Program Files (x86)/OpenIV/OpenIV.exe"
        "$PREFIX_DIR/drive_c/Program Files/OpenIV/OpenIV Launcher.exe"
        "$PREFIX_DIR/drive_c/Program Files (x86)/OpenIV/OpenIV Launcher.exe"
    )
    for p in "${paths[@]}"; do
        if [ -f "$p" ]; then OPENIV_EXE="$p"; log_ok "Found: $p"; return 0; fi
    done

    local found
    found=$(find "$PREFIX_DIR/drive_c" -maxdepth 4 -name "OpenIV*.exe" -type f 2>/dev/null | head -1 || true)
    if [ -n "$found" ]; then OPENIV_EXE="$found"; log_ok "Found: $found"; return 0; fi

    log_warn "OpenIV executable not found"
    return 1
}

create_launchers() {
    log_header "Desktop Integration"

    local desktop_dir="${XDG_DATA_HOME}/applications"
    local icons_dir="${XDG_DATA_HOME}/icons"
    mkdir -p "$desktop_dir" "$icons_dir"

    local icon_path="$icons_dir/openiv.png"
    local desktop_file="$desktop_dir/openiv.desktop"

    if [ -n "$APPDIR" ] && [ -f "$APPDIR/openiv.png" ]; then
        cp "$APPDIR/openiv.png" "$icon_path"
    fi

    cat > "$LAUNCHER_SCRIPT" << WRAPEOF
#!/bin/bash
# OpenIV launcher – generated by OpenIVLinuxInstaller v5
export WINEPREFIX="$PREFIX_DIR"
export WINEARCH="win32"
export WINEDEBUG="${WINEDEBUG:--all}"
exec "$WINE_BINARY" "\$@"
WRAPEOF
    chmod +x "$LAUNCHER_SCRIPT"

    cat > "$desktop_file" << DESKTOPEOF
[Desktop Entry]
Name=OpenIV
Comment=The ultimate modding tool for GTA V, GTA IV and Max Payne 3
Exec=$LAUNCHER_SCRIPT "$OPENIV_EXE"
Icon=$icon_path
Terminal=false
Type=Application
Categories=Game;Utility;
StartupWMClass=openiv.exe
StartupNotify=true
DESKTOPEOF

    log_ok "Desktop entry: $desktop_file"
    log_ok "Launcher script: $LAUNCHER_SCRIPT"

    local shell_rc=""
    [ -f "$HOME/.bashrc" ] && shell_rc="$HOME/.bashrc"
    [ -z "$shell_rc" ] && [ -f "$HOME/.zshrc" ] && shell_rc="$HOME/.zshrc"
    if [ -n "$shell_rc" ] && ! grep -q "alias openiv=" "$shell_rc" 2>/dev/null; then
        { echo ""; echo "# OpenIV launcher"; echo "alias openiv='$LAUNCHER_SCRIPT \"$OPENIV_EXE\"'"; } >> "$shell_rc"
        log_ok "Added 'openiv' alias to $shell_rc"
    fi
}

print_summary() {
    echo ""; log_header "Installation Complete"; echo ""
    echo -e "  ${GREEN}OpenIV is installed and configured.${NC}"
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
    export WINEPREFIX="$PREFIX_DIR" WINEARCH="win32" WINEDEBUG="${WINEDEBUG:--all}"
    exec "$WINE_BINARY" "$OPENIV_EXE"
}

main() {
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║${NC}          ${BOLD}OpenIV Linux Installer v5${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}          ${GREEN}[Offline – bundled Wine + installer + runtime prefix]${NC} ${CYAN}║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ -z "$APPDIR" ]; then
        log_err "This script must run from within the OpenIV AppImage."
        log_err "Download the AppImage from https://github.com/NecroArab/OpenIVLinuxInstaller/releases"
        exit 1
    fi

    if [ ! -x "$WINE_BINARY" ]; then
        log_err "Bundled Wine not found at $BUNDLED_WINE"
        exit 1
    fi

    mkdir -p "$PREFIX_DIR"

    ensure_prefix
    install_openiv_silent

    if verify_installation; then
        create_launchers
        print_summary
        launch_openiv
    else
        log_warn "OpenIV executable not found. Installer may have failed."
        log_warn "Check $PREFIX_DIR/drive_c/Program Files/OpenIV/ manually."
        exit 5
    fi
}

main "$@"
