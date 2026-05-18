#!/bin/bash
################################################################################
# OpenIV Linux Installer — Portable, Zero-Input, Rootless AppImage Wrapper
#
# Downloads a portable Wine runtime, creates a Wine prefix, installs .NET,
# downloads & installs OpenIV, detects GTA V, and creates self-contained
# desktop launchers — all without sudo, package managers, or user prompts.
#
# Usage:  chmod +x OpenIVLinuxInstaller.sh && ./OpenIVLinuxInstaller.sh
################################################################################
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Shell & Self-Exec Guard
# ──────────────────────────────────────────────────────────────────────────────
if [ -z "${BASH_VERSION:-}" ]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    fi
    echo "This script must be run with bash" >&2
    exit 1
fi

# ──────────────────────────────────────────────────────────────────────────────
# Paths  (all under $HOME, no root)
# ──────────────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPDIR="${APPDIR:-$SCRIPT_DIR}"          # AppImage mount point when bundled
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

DATA_DIR="$XDG_DATA_HOME/openiv-linux"
PREFIX_DIR="$DATA_DIR/prefix"
DOWNLOADS_DIR="$DATA_DIR/downloads"
RUNTIME_DIR="$DATA_DIR/wine-runtime"
BIN_DIR="$DATA_DIR/bin"

CACHE_DIR="$DATA_DIR/cache"
WINE_CACHE_DIR="$CACHE_DIR/wine"

WINE_VERSION="11.9"
WINE_FLAVOR="staging-amd64-wow64"
WINE_TAG="$WINE_VERSION"
WINE_TARBALL="wine-${WINE_VERSION}-${WINE_FLAVOR}.tar.xz"
WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_TAG}/${WINE_TARBALL}"
WINE_DIR="$RUNTIME_DIR/wine-${WINE_VERSION}-${WINE_FLAVOR}"
WINE_BINARY="$WINE_DIR/bin/wine"
WINE_SERVER="$WINE_DIR/bin/wineserver"
WINEBOOT="$WINE_DIR/bin/wineboot"
WINE_CFG="$WINE_DIR/bin/winecfg"

WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
WINETRICKS_BIN="$BIN_DIR/winetricks"

OPENIV_INSTALLER_URL="https://openiv.com/webiv/guest.php?get=0"
OPENIV_INSTALLER="$DOWNLOADS_DIR/ovisetup.exe"

OPENIV_EXE=""

# ──────────────────────────────────────────────────────────────────────────────
# Terminal Colors  (safe for non-TTY)
# ──────────────────────────────────────────────────────────────────────────────
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

# ──────────────────────────────────────────────────────────────────────────────
# Download Helper  (curl preferred, wget fallback; silent, no progress)
# ──────────────────────────────────────────────────────────────────────────────
silent_download() {
    local url="$1" out="$2" desc="$3"
    log_step "Downloading $desc ..."
    mkdir -p "$(dirname "$out")"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$out" && { log_ok "$desc — done"; return 0; }
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$out" && { log_ok "$desc — done"; return 0; }
    fi
    log_err "Failed to download $desc (neither curl nor wget succeeded)"
    return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# 1.  Directory Setup
# ──────────────────────────────────────────────────────────────────────────────
setup_directories() {
    mkdir -p "$PREFIX_DIR" "$DOWNLOADS_DIR" "$RUNTIME_DIR" "$BIN_DIR" "$CACHE_DIR" "$WINE_CACHE_DIR"
}

# ──────────────────────────────────────────────────────────────────────────────
# 2.  Portable Wine Runtime
# ──────────────────────────────────────────────────────────────────────────────
ensure_portable_wine() {
    log_header "Portable Wine Runtime"

    # Already deployed?
    if [ -x "$WINE_BINARY" ]; then
        local ver
        ver=$("$WINE_BINARY" --version 2>/dev/null || echo "unknown")
        log_ok "Portable Wine $ver found at $WINE_DIR"
        return 0
    fi

    # Bundled inside AppImage?
    local bundled="$APPDIR/$WINE_TARBALL"
    if [ -f "$bundled" ]; then
        log_step "Extracting bundled Wine from AppImage ..."
        tar -xJf "$bundled" -C "$RUNTIME_DIR" 2>/dev/null || {
            log_err "Failed to extract bundled Wine tarball"
            exit 2
        }
    else
        # Download from Kron4ek
        local tarball_path="$WINE_CACHE_DIR/$WINE_TARBALL"
        if [ ! -f "$tarball_path" ]; then
            silent_download "$WINE_URL" "$tarball_path" "Wine ${WINE_VERSION} (${WINE_FLAVOR})"
        else
            log_ok "Wine tarball already cached"
        fi
        log_step "Extracting Wine (this may take a moment) ..."
        tar -xJf "$tarball_path" -C "$RUNTIME_DIR" 2>/dev/null || {
            log_err "Failed to extract Wine tarball (corrupt download?); remove $tarball_path and retry"
            exit 2
        }
    fi

    if [ ! -x "$WINE_BINARY" ]; then
        log_err "Wine binary not found after extraction at $WINE_BINARY"
        exit 2
    fi

    local ver
    ver=$("$WINE_BINARY" --version 2>/dev/null || echo "unknown")
    log_ok "Portable Wine $ver ready at $WINE_DIR"
}

# ──────────────────────────────────────────────────────────────────────────────
# 3.  Winetricks  (download if system copy missing)
# ──────────────────────────────────────────────────────────────────────────────
ensure_winetricks() {
    log_header "Winetricks"

    # Prefer system winetricks if available and recent enough
    if command -v winetricks >/dev/null 2>&1; then
        local sys_ver
        sys_ver=$(winetricks --version 2>/dev/null | head -1 || echo "0")
        log_ok "Using system winetricks ($sys_ver)"
        WINETRICKS_BIN="$(command -v winetricks)"
        return 0
    fi

    if [ -x "$WINETRICKS_BIN" ]; then
        log_ok "Local winetricks found at $WINETRICKS_BIN"
        return 0
    fi

    silent_download "$WINETRICKS_URL" "$WINETRICKS_BIN" "winetricks"
    chmod +x "$WINETRICKS_BIN"
    log_ok "Local winetricks ready"
}

# ──────────────────────────────────────────────────────────────────────────────
# 4.  Wine Prefix  (silent, no dialogs)
# ──────────────────────────────────────────────────────────────────────────────
create_wine_prefix() {
    log_header "Wine Prefix"

    # Kill leftover processes
    WINEPREFIX="$PREFIX_DIR" "$WINE_SERVER" -k 2>/dev/null || true

    export WINEPREFIX="$PREFIX_DIR"
    export WINEARCH="win64"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    export WINEDEBUG="${WINEDEBUG:--all}"
    PATH="$WINE_DIR/bin:$PATH"

    log_step "Initialising Wine prefix ..."
    "$WINEBOOT" -u 2>/dev/null || {
        log_err "wineboot failed — cannot create Wine prefix"
        exit 3
    }

    if [ ! -d "$PREFIX_DIR/drive_c" ]; then
        log_err "Wine prefix directory not created"
        exit 3
    fi
    log_ok "Prefix created at $PREFIX_DIR"

    # Prevent Mono/Gecko GUI prompts
    mkdir -p "$PREFIX_DIR/drive_c/windows/system32"

    # Set Windows 10
    log_step "Setting Windows version to 10 ..."
    "$WINETRICKS_BIN" -q win10 2>/dev/null || log_warn "win10 verb had non-zero exit"
    log_ok "Windows 10 set"
}

# ──────────────────────────────────────────────────────────────────────────────
# 5.  .NET 4.8 + VC++ + D3D via winetricks  (unattended, may take 10-20 min)
# ──────────────────────────────────────────────────────────────────────────────
install_prefix_deps() {
    log_header "Wine Prefix Dependencies"

    export WINEPREFIX="$PREFIX_DIR"
    export WINEARCH="win64"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    export WINEDEBUG="${WINEDEBUG:--all}"
    PATH="$WINE_DIR/bin:$PATH"
    WINETRICKS_DOWNLOADER="${WINETRICKS_DOWNLOADER:-curl}"

    log_step "Installing .NET Framework 4.8 (10-20 min) ..."
    "$WINETRICKS_BIN" -q dotnet48 2>/dev/null || log_warn "dotnet48 exit code non-zero (may be benign)"

    log_step "Installing Visual C++ 2019 redistributable ..."
    "$WINETRICKS_BIN" -q vcrun2019 2>/dev/null || log_warn "vcrun2019 exit code non-zero"

    log_step "Installing DirectX 11.43 runtime ..."
    "$WINETRICKS_BIN" -q d3dx11_43 2>/dev/null || log_warn "d3dx11_43 exit code non-zero"

    log_step "Installing corefonts ..."
    "$WINETRICKS_BIN" -q corefonts 2>/dev/null || log_warn "corefonts exit code non-zero"

    # Kill wine processes so subsequent steps start fresh
    "$WINE_SERVER" -k 2>/dev/null || true
    log_ok "Prefix dependencies installed"
}

# ──────────────────────────────────────────────────────────────────────────────
# 6.  OpenIV Installer Download  (silent, no prompt)
# ──────────────────────────────────────────────────────────────────────────────
download_openiv_installer() {
    log_header "OpenIV Installer"

    if [ -f "$OPENIV_INSTALLER" ] && [ -s "$OPENIV_INSTALLER" ]; then
        log_ok "Installer already present ($(du -h "$OPENIV_INSTALLER" | cut -f1))"
        return 0
    fi

    silent_download "$OPENIV_INSTALLER_URL" "$OPENIV_INSTALLER" "OpenIV installer from openiv.com"

    if [ ! -s "$OPENIV_INSTALLER" ]; then
        log_err "Downloaded file is empty"
        exit 4
    fi
    log_ok "Installer saved ($(du -h "$OPENIV_INSTALLER" | cut -f1))"
}

# ──────────────────────────────────────────────────────────────────────────────
# 7.  OpenIV Silent Install
# ──────────────────────────────────────────────────────────────────────────────
install_openiv_silent() {
    log_header "Installing OpenIV"

    export WINEPREFIX="$PREFIX_DIR"
    export WINEARCH="win64"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    export WINEDEBUG="${WINEDEBUG:--all}"
    PATH="$WINE_DIR/bin:$PATH"

    log_step "Running installer (InnoSetup /VERYSILENT) ..."
    "$WINE_BINARY" "$OPENIV_INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- 2>/dev/null || \
        log_warn "Installer exit code non-zero — check $PREFIX_DIR/drive_c/Program Files/OpenIV/ manually"

    "$WINE_SERVER" -k 2>/dev/null || true
    log_ok "Installation phase complete"
}

# ──────────────────────────────────────────────────────────────────────────────
# 8.  GTA V Auto-Detection  →  symlink to C:\GTA5
# ──────────────────────────────────────────────────────────────────────────────
detect_gta_v() {
    log_header "GTA V Detection"

    local gta5_dir=""
    local candidates=(
        "$HOME/.steam/steam/steamapps/common/Grand Theft Auto V"
        "$HOME/.local/share/Steam/steamapps/common/Grand Theft Auto V"
        "$HOME/.var/app/com.valvesoftware.Steam/.steam/steam/steamapps/common/Grand Theft Auto V"
        "$HOME/Games/Heroic/GrandTheftAutoV"
        "$HOME/Games/grand-theft-auto-v"
        "$HOME/Games/Grand Theft Auto V"
    )

    for c in "${candidates[@]}"; do
        if [ -d "$c" ] && [ -f "$c/GTA5.exe" -o -f "$c/PlayGTAV.exe" ]; then
            gta5_dir="$c"
            break
        fi
    done

    # Search a broader range of Steam library folders via libraryfolders.vdf
    if [ -z "$gta5_dir" ]; then
        local vdf
        for vdf in "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
                    "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"; do
            if [ -f "$vdf" ]; then
                while IFS= read -r path; do
                    path="${path%\"}"; path="${path#\"}"
                    local candidate="$path/steamapps/common/Grand Theft Auto V"
                    if [ -d "$candidate" ] && [ -f "$candidate/GTA5.exe" ]; then
                        gta5_dir="$candidate"
                        break 2
                    fi
                done < <(grep -oP '"\d+"\s+"\K[^"]+' "$vdf" 2>/dev/null || true)
            fi
        done
    fi

    if [ -z "$gta5_dir" ]; then
        log_warn "GTA V installation not found on any known path (Steam/Heroic/Lutris)."
        log_warn "To use OpenIV with GTA V, symlink your game folder manually:"
        log_warn "  ln -s /path/to/GTA\\ V \"$PREFIX_DIR/drive_c/GTA5\""
        return 0
    fi

    local symlink_target="$PREFIX_DIR/drive_c/GTA5"
    if [ -L "$symlink_target" ] || [ -d "$symlink_target" ]; then
        log_ok "GTA V already linked at C:\\GTA5"
        return 0
    fi

    ln -sf "$gta5_dir" "$symlink_target"
    log_ok "GTA V found at: $gta5_dir"
    log_ok "Symlinked to C:\\GTA5"
}

# ──────────────────────────────────────────────────────────────────────────────
# 9.  Verification
# ──────────────────────────────────────────────────────────────────────────────
verify_installation() {
    log_header "Verification"

    export WINEPREFIX="$PREFIX_DIR"

    local paths=(
        "$PREFIX_DIR/drive_c/Program Files/OpenIV/OpenIV.exe"
        "$PREFIX_DIR/drive_c/Program Files (x86)/OpenIV/OpenIV.exe"
        "$PREFIX_DIR/drive_c/Program Files/OpenIV/OpenIV Launcher.exe"
        "$PREFIX_DIR/drive_c/Program Files (x86)/OpenIV/OpenIV Launcher.exe"
    )

    for p in "${paths[@]}"; do
        if [ -f "$p" ]; then
            OPENIV_EXE="$p"
            log_ok "OpenIV executable found: $p"
            return 0
        fi
    done

    # Broader search
    local found
    found=$(find "$PREFIX_DIR/drive_c" -maxdepth 4 -name "OpenIV*.exe" -type f 2>/dev/null | head -1 || true)
    if [ -n "$found" ]; then
        OPENIV_EXE="$found"
        log_ok "OpenIV executable found: $found"
        return 0
    fi

    log_warn "OpenIV executable not found after installation."
    return 1
}

# ──────────────────────────────────────────────────────────────────────────────
# 10. Launcher Script & Desktop Entry  (point to portable Wine)
# ──────────────────────────────────────────────────────────────────────────────
create_launchers() {
    log_header "Desktop Integration"

    local desktop_dir="${XDG_DATA_HOME}/applications"
    local icons_dir="${XDG_DATA_HOME}/icons"
    mkdir -p "$desktop_dir" "$icons_dir"

    local icon_path="$icons_dir/openiv.png"
    local desktop_file="$desktop_dir/openiv.desktop"
    local wrapper_script="$DATA_DIR/run-openiv.sh"

    # Bundle icon from AppImage if available, otherwise embed minimal PNG
    if [ -f "$APPDIR/openiv.png" ]; then
        cp "$APPDIR/openiv.png" "$icon_path"
    elif [ ! -f "$icon_path" ]; then
        # Tiny valid 1x1 PNG placeholder
        printf '\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\000\001\000\000\000\001\010\002\000\000\000\220wS\336\000\000\000\022IDATx\234c\370\017\000\000\001\001\001\002\370\217\374\351\000\000\000\000IEND\246B`\202' > "$icon_path"
    fi

    # Wrapper — sources the portable Wine environment
    cat > "$wrapper_script" << WRAPEOF
#!/bin/bash
# OpenIV launcher — generated by OpenIVLinuxInstaller
export WINEPREFIX="$PREFIX_DIR"
export WINEARCH="win64"
export WINEDEBUG="${WINEDEBUG:--all}"
export PATH="$WINE_DIR/bin:\$PATH"

# Gamescope wrapper (if available)
if command -v gamescope >/dev/null 2>&1; then
    exec gamescope -f -- "$WINE_BINARY" "\$@"
else
    exec "$WINE_BINARY" "\$@"
fi
WRAPEOF
    chmod +x "$wrapper_script"

    cat > "$desktop_file" << DESKTOPEOF
[Desktop Entry]
Name=OpenIV
Comment=The ultimate modding tool for GTA V, GTA IV and Max Payne 3
Exec=$wrapper_script "$OPENIV_EXE"
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
    if [ -f "$HOME/.bashrc" ]; then shell_rc="$HOME/.bashrc"; fi
    if [ -f "$HOME/.zshrc" ] && [ -z "$shell_rc" ]; then shell_rc="$HOME/.zshrc"; fi
    if [ -n "$shell_rc" ] && ! grep -q "alias openiv=" "$shell_rc" 2>/dev/null; then
        {
            echo ""
            echo "# OpenIV launcher (portable Wine)"
            echo "alias openiv='$wrapper_script \"$OPENIV_EXE\"'"
        } >> "$shell_rc"
        log_ok "Added 'openiv' alias to $shell_rc"
    fi
}

# ──────────────────────────────────────────────────────────────────────────────
# 11. Summary & Launch
# ──────────────────────────────────────────────────────────────────────────────
print_summary() {
    echo ""
    log_header "Installation Complete"
    echo ""
    echo -e "  ${GREEN}OpenIV has been installed and configured.${NC}"
    echo ""
    echo -e "  ${BOLD}Launch methods:${NC}"
    echo -e "    ${GREEN}1.${NC} Terminal: ${CYAN}openiv${NC}"
    echo -e "    ${GREEN}2.${NC} Application menu: ${CYAN}OpenIV${NC}"
    echo -e "    ${GREEN}3.${NC} Direct: ${CYAN}WINEPREFIX=\"$PREFIX_DIR\" \"$WINE_BINARY\" \"$OPENIV_EXE\"${NC}"
    echo ""
    echo -e "  ${BOLD}Uninstall:${NC}  ${CYAN}rm -rf \"$DATA_DIR\"${NC}"
    echo -e "  ${BOLD}Wine dir:${NC}   ${CYAN}$WINE_DIR${NC}"
    echo -e "  ${BOLD}Prefix:${NC}     ${CYAN}$PREFIX_DIR${NC}"
    echo ""
}

launch_openiv() {
    if [ -z "$OPENIV_EXE" ] || [ ! -f "$OPENIV_EXE" ]; then
        log_warn "OpenIV executable unavailable — skipping launch."
        return
    fi

    echo ""
    log_header "Launching OpenIV"
    echo ""

    export WINEPREFIX="$PREFIX_DIR"
    export WINEARCH="win64"
    export WINEDEBUG="${WINEDEBUG:--all}"
    PATH="$WINE_DIR/bin:$PATH"

    exec "$WINE_BINARY" "$OPENIV_EXE"
}

# ──────────────────────────────────────────────────────────────────────────────
# Main  (idempotent: safe to re-run)
# ──────────────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║${NC}          ${BOLD}OpenIV Linux Installer  (zero-input edition)${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    setup_directories
    ensure_portable_wine
    ensure_winetricks

    # Create prefix if missing
    if [ ! -f "$PREFIX_DIR/drive_c/windows/system32/kernel32.dll" ]; then
        create_wine_prefix
        install_prefix_deps
    else
        log_ok "Existing Wine prefix at $PREFIX_DIR — skipping recreation"
    fi

    # OpenIV installer
    download_openiv_installer
    install_openiv_silent

    # GTA V auto-link
    detect_gta_v

    # Verify & finalise
    if verify_installation; then
        create_launchers
        print_summary
        launch_openiv
    else
        log_warn "OpenIV executable not found. Installer may have failed silently."
        log_warn "Check $PREFIX_DIR/drive_c/Program Files/OpenIV/ manually."
        exit 5
    fi
}

main "$@"
