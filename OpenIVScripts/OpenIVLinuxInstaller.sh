#!/bin/bash
################################################################################
# OpenIV Linux Installer  –  Self-Contained, Zero-Input, AppImage-Ready
#
# When executed inside an AppImage ($APPDIR is set) the script uses the
# pre-bundled Wine runtime and pre-baked prefix (with .NET 4.8 already
# installed) – first run is ~3 seconds instead of 20 minutes.
#
# When executed standalone (plain .sh) it falls back to downloading a
# portable Wine build and installing deps dynamically.
#
# OpenIV setup binary is downloaded from openiv.com with multi-tier
# fallback (SSL bypass → gta5-mods.com mirror scraping).
#
# Usage:  chmod +x OpenIVLinuxInstaller.sh && ./OpenIVLinuxInstaller.sh
################################################################################
set -euo pipefail

# ── Shell / Self-Exec Guard ───────────────────────────────────────────────────
if [ -z "${BASH_VERSION:-}" ]; then
    command -v bash >/dev/null 2>&1 && exec bash "$0" "$@"
    echo "This script requires bash" >&2; exit 1
fi

# ── Paths ──────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPDIR="${APPDIR:-}"                       # set by AppImage runtime when bundled
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

DATA_DIR="$XDG_DATA_HOME/openiv-linux"
PREFIX_DIR="$DATA_DIR/prefix"
DOWNLOADS_DIR="$DATA_DIR/downloads"
RUNTIME_DIR="$DATA_DIR/wine-runtime"
BIN_DIR="$DATA_DIR/bin"
CACHE_DIR="$DATA_DIR/cache"
WINE_CACHE_DIR="$CACHE_DIR/wine"

# Bundled resource paths  (inside the AppImage)
BUNDLED_WINE_DIR="$APPDIR/usr/share/openiv/wine"
BUNDLED_PREFIX_TARBALL="$APPDIR/usr/share/openiv/prefix.tar.xz"

# Standalone Wine download (Kron4ek)
WINE_VERSION="11.9"
WINE_FLAVOR="staging-amd64-wow64"
WINE_TARBALL="wine-${WINE_VERSION}-${WINE_FLAVOR}.tar.xz"
WINE_URL="https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VERSION}/${WINE_TARBALL}"

# Resolved at runtime
WINE_DIR=""
WINE_BINARY=""
WINE_SERVER=""

# Winetricks (only used in standalone mode)
WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
WINETRICKS_BIN="$BIN_DIR/winetricks"

# OpenIV download sources (tiered fallback)
OPENIV_URL_PRIMARY="https://openiv.com/webiv/guest.php?get=0"
OPENIV_URL_GTA5MODS="https://www.gta5-mods.com/tools/openiv"
OPENIV_INSTALLER="$DOWNLOADS_DIR/ovisetup.exe"

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

# ── Helpers ────────────────────────────────────────────────────────────────────
silent_download() {
    local url="$1" out="$2" desc="$3"
    log_step "Downloading $desc …"
    mkdir -p "$(dirname "$out")"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$out" 2>/dev/null && { log_ok "$desc — done"; return 0; }
        # SSL error 60 → retry with --insecure
        curl -fksSL "$url" -o "$out" 2>/dev/null && { log_ok "$desc — done (insecure)"; return 0; }
    fi
    if command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$out" 2>/dev/null && { log_ok "$desc — done"; return 0; }
        wget --no-check-certificate -q "$url" -O "$out" 2>/dev/null && { log_ok "$desc — done (no-check)"; return 0; }
    fi
    return 1
}

download_with_fallback() {
    local desc="$1"
    mkdir -p "$(dirname "$OPENIV_INSTALLER")"

    # ── Tier 1 : openiv.com with SSL bypass ──
    log_step "Tier 1 — openiv.com …"
    local url="$OPENIV_URL_PRIMARY"

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$url" -o "$OPENIV_INSTALLER" 2>/dev/null && [ -s "$OPENIV_INSTALLER" ]; then
            log_ok "Downloaded from openiv.com (curl)"; return 0; fi
        if curl -fksSL "$url" -o "$OPENIV_INSTALLER" 2>/dev/null && [ -s "$OPENIV_INSTALLER" ]; then
            log_ok "Downloaded from openiv.com (curl, insecure)"; return 0; fi
    fi
    if command -v wget >/dev/null 2>&1; then
        if wget -q "$url" -O "$OPENIV_INSTALLER" 2>/dev/null && [ -s "$OPENIV_INSTALLER" ]; then
            log_ok "Downloaded from openiv.com (wget)"; return 0; fi
        if wget --no-check-certificate -q "$url" -O "$OPENIV_INSTALLER" 2>/dev/null && [ -s "$OPENIV_INSTALLER" ]; then
            log_ok "Downloaded from openiv.com (wget, no-check)"; return 0; fi
    fi

    # ── Tier 2 : scrape gta5-mods.com for a download link ──
    log_warn "openiv.com failed — trying gta5-mods.com …"

    local mods_page
    mods_page=$(mktemp)
    local mods_url=""

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$OPENIV_URL_GTA5MODS" -o "$mods_page" 2>/dev/null || \
        curl -fksSL "$OPENIV_URL_GTA5MODS" -o "$mods_page" 2>/dev/null || true
    fi
    if [ ! -s "$mods_page" ] && command -v wget >/dev/null 2>&1; then
        wget -q "$OPENIV_URL_GTA5MODS" -O "$mods_page" 2>/dev/null || \
        wget --no-check-certificate -q "$OPENIV_URL_GTA5MODS" -O "$mods_page" 2>/dev/null || true
    fi

    if [ -s "$mods_page" ]; then
        # Try to find a download link – gta5-mods typically uses:
        #   <a href="/tools/openiv/download?...">Download</a>
        #   or a data-direct link.
        mods_url="$(grep -oP 'href="([^"]*openiv[^"]*download[^"]*)"' "$mods_page" | head -1 | sed 's/href="//;s/"//')"
        if [ -z "$mods_url" ]; then
            mods_url="$(grep -oP 'href="([^"]*download[^"]*\.exe[^"]*)"' "$mods_page" | head -1 | sed 's/href="//;s/"//')"
        fi
        if [ -n "$mods_url" ]; then
            [[ "$mods_url" =~ ^/ ]] && mods_url="https://www.gta5-mods.com${mods_url}"
            [[ "$mods_url" =~ ^// ]] && mods_url="https:${mods_url}"
            log_step "Tier 2 — gta5-mods.com mirror …"
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL "$mods_url" -o "$OPENIV_INSTALLER" 2>/dev/null && [ -s "$OPENIV_INSTALLER" ] && { log_ok "Downloaded from gta5-mods.com"; rm -f "$mods_page"; return 0; }
                curl -fksSL "$mods_url" -o "$OPENIV_INSTALLER" 2>/dev/null && [ -s "$OPENIV_INSTALLER" ] && { log_ok "Downloaded from gta5-mods.com (insecure)"; rm -f "$mods_page"; return 0; }
            fi
            if command -v wget >/dev/null 2>&1; then
                wget -q "$mods_url" -O "$OPENIV_INSTALLER" 2>/dev/null && [ -s "$OPENIV_INSTALLER" ] && { log_ok "Downloaded from gta5-mods.com"; rm -f "$mods_page"; return 0; }
                wget --no-check-certificate -q "$mods_url" -O "$OPENIV_INSTALLER" 2>/dev/null && [ -s "$OPENIV_INSTALLER" ] && { log_ok "Downloaded from gta5-mods.com (no-check)"; rm -f "$mods_page"; return 0; }
            fi
        fi
    fi
    rm -f "$mods_page"

    # ── Tier 3 : all sources exhausted ──
    log_err "All download sources failed."
    log_err "Visit https://openiv.com/ manually and place ovisetup.exe at:"
    log_err "  $OPENIV_INSTALLER"
    return 1
}

# ── 1. Directory Setup ────────────────────────────────────────────────────────
setup_directories() {
    mkdir -p "$PREFIX_DIR" "$DOWNLOADS_DIR" "$RUNTIME_DIR" "$BIN_DIR" "$CACHE_DIR" "$WINE_CACHE_DIR"
}

# ── 2. Wine Runtime  (bundled in AppImage / downloaded for standalone) ────────
ensure_wine() {
    log_header "Wine Runtime"

    # Scenario A – Bundled in AppImage
    if [ -n "$APPDIR" ] && [ -x "$BUNDLED_WINE_DIR/bin/wine" ]; then
        WINE_DIR="$BUNDLED_WINE_DIR"
        WINE_BINARY="$WINE_DIR/bin/wine"
        WINE_SERVER="$WINE_DIR/bin/wineserver"
        local ver; ver=$("$WINE_BINARY" --version 2>/dev/null || echo "bundled")
        log_ok "Using bundled Wine $ver from AppImage"
        return 0
    fi

    # Scenario B – Already deployed locally
    local local_candidate="$RUNTIME_DIR/wine-${WINE_VERSION}-${WINE_FLAVOR}"
    if [ -x "$local_candidate/bin/wine" ]; then
        WINE_DIR="$local_candidate"
        WINE_BINARY="$WINE_DIR/bin/wine"
        WINE_SERVER="$WINE_DIR/bin/wineserver"
        local ver; ver=$("$WINE_BINARY" --version 2>/dev/null || echo "cached")
        log_ok "Using cached Wine $ver from $WINE_DIR"
        return 0
    fi

    # Scenario C – Download portable Wine
    log_step "No bundled or cached Wine found – downloading portable build …"
    local tarball_path="$WINE_CACHE_DIR/$WINE_TARBALL"
    if [ ! -f "$tarball_path" ]; then
        silent_download "$WINE_URL" "$tarball_path" "Wine ${WINE_VERSION} (${WINE_FLAVOR})"
    else
        log_ok "Wine tarball already cached"
    fi

    log_step "Extracting …"
    tar -xJf "$tarball_path" -C "$RUNTIME_DIR" 2>/dev/null || {
        log_err "Extraction failed – corrupt tarball? Remove $tarball_path and retry."
        exit 2
    }

    if [ ! -x "$local_candidate/bin/wine" ]; then
        log_err "Wine binary not found after extraction"
        exit 2
    fi

    WINE_DIR="$local_candidate"
    WINE_BINARY="$WINE_DIR/bin/wine"
    WINE_SERVER="$WINE_DIR/bin/wineserver"
    local ver; ver=$("$WINE_BINARY" --version 2>/dev/null || echo "downloaded")
    log_ok "Wine $ver ready"
}

# ── 3. Winetricks (only needed in standalone / prefix-build mode) ─────────────
ensure_winetricks() {
    if command -v winetricks >/dev/null 2>&1; then
        WINETRICKS_BIN="$(command -v winetricks)"
        return 0
    fi
    if [ -x "$WINETRICKS_BIN" ]; then
        return 0
    fi
    silent_download "$WINETRICKS_URL" "$WINETRICKS_BIN" "winetricks"
    chmod +x "$WINETRICKS_BIN"
}

# ── 4. Wine Prefix  (pre-baked tarball / build from scratch) ──────────────────
ensure_prefix() {
    log_header "Wine Prefix"

    # Already deployed?
    if [ -f "$PREFIX_DIR/drive_c/windows/system32/kernel32.dll" ]; then
        log_ok "Prefix already exists at $PREFIX_DIR"
        return 0
    fi

    # Scenario A – Extract pre-baked prefix tarball from AppImage
    if [ -n "$APPDIR" ] && [ -f "$BUNDLED_PREFIX_TARBALL" ]; then
        log_step "Extracting pre-baked prefix (with .NET 4.8 pre-installed) …"
        mkdir -p "$PREFIX_DIR"
        tar -xJf "$BUNDLED_PREFIX_TARBALL" -C "$PREFIX_DIR" 2>/dev/null || {
            log_err "Prefix tarball extraction failed"
            exit 3
        }
        if [ -f "$PREFIX_DIR/drive_c/windows/system32/kernel32.dll" ]; then
            log_ok "Prefix extracted (size: $(du -sh "$PREFIX_DIR" | cut -f1))"
            return 0
        fi
        log_warn "Prefix tarball extraction produced an incomplete prefix – falling back to build"
        rm -rf "$PREFIX_DIR"
    fi

    # Scenario B – Build from scratch (standalone .sh mode)
    log_step "Creating prefix from scratch (standalone mode) …"
    export WINEPREFIX="$PREFIX_DIR"
    export WINEARCH="win64"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    export WINEDEBUG="${WINEDEBUG:--all}"
    PATH="$WINE_DIR/bin:$PATH"

    "$WINE_SERVER" -k 2>/dev/null || true

    log_step "Initialising …"
    "$WINE_DIR/bin/wineboot" -u 2>/dev/null || { log_err "wineboot failed"; exit 3; }
    if [ ! -d "$PREFIX_DIR/drive_c" ]; then log_err "drive_c not created"; exit 3; fi
    log_ok "Prefix created"

    log_step "Setting Windows 10 …"
    "$WINETRICKS_BIN" -q win10 2>/dev/null || log_warn "win10 exit non-zero"

    log_step "Installing .NET Framework 4.8 (10-20 min) …"
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

# ── 5. OpenIV Installer Download ──────────────────────────────────────────────
download_openiv_installer() {
    log_header "OpenIV Installer"

    if [ -f "$OPENIV_INSTALLER" ] && [ -s "$OPENIV_INSTALLER" ]; then
        log_ok "Installer already present ($(du -h "$OPENIV_INSTALLER" | cut -f1))"
        return 0
    fi

    download_with_fallback "OpenIV setup from openiv.com"
    if [ ! -s "$OPENIV_INSTALLER" ]; then
        log_err "Downloaded file is empty after all fallback attempts"
        exit 4
    fi
    log_ok "Installer saved ($(du -h "$OPENIV_INSTALLER" | cut -f1))"
}

# ── 6. OpenIV Silent Install ──────────────────────────────────────────────────
install_openiv_silent() {
    log_header "Installing OpenIV"

    export WINEPREFIX="$PREFIX_DIR"
    export WINEARCH="win64"
    export WINEDLLOVERRIDES="winemenubuilder.exe=d"
    export WINEDEBUG="${WINEDEBUG:--all}"
    PATH="$WINE_DIR/bin:$PATH"

    log_step "Running installer (InnoSetup /VERYSILENT) …"
    "$WINE_BINARY" "$OPENIV_INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- 2>/dev/null || \
        log_warn "Installer exit code non-zero"

    "$WINE_SERVER" -k 2>/dev/null || true
    log_ok "Installation phase complete"
}

# ── 7. GTA V Auto-Detection  →  symlink to C:\GTA5 ───────────────────────────
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
        if [ -d "$c" ] && { [ -f "$c/GTA5.exe" ] || [ -f "$c/PlayGTAV.exe" ]; }; then
            gta5_dir="$c"; break
        fi
    done

    # Scan Steam libraryfolders.vdf for extra library paths
    if [ -z "$gta5_dir" ]; then
        for vdf in "$HOME/.steam/steam/steamapps/libraryfolders.vdf" \
                   "$HOME/.local/share/Steam/steamapps/libraryfolders.vdf"; do
            [ -f "$vdf" ] || continue
            while IFS= read -r path; do
                path="${path%\"}"; path="${path#\"}"
                local cand="$path/steamapps/common/Grand Theft Auto V"
                if [ -d "$cand" ] && [ -f "$cand/GTA5.exe" ]; then
                    gta5_dir="$cand"; break 2
                fi
            done < <(grep -oP '"\d+"\s+"\K[^"]+' "$vdf" 2>/dev/null || true)
        done
    fi

    if [ -z "$gta5_dir" ]; then
        log_warn "GTA V not found (Steam/Heroic/Lutris)."
        log_warn "To link manually:  ln -s /path/to/GTA\\ V \"$PREFIX_DIR/drive_c/GTA5\""
        return 0
    fi

    local symlink_target="$PREFIX_DIR/drive_c/GTA5"
    if [ -L "$symlink_target" ] || [ -d "$symlink_target" ]; then
        log_ok "GTA V already linked at C:\\GTA5"
        return 0
    fi

    ln -sf "$gta5_dir" "$symlink_target"
    log_ok "GTA V symlinked to C:\\GTA5"
}

# ── 8. Verification ───────────────────────────────────────────────────────────
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
        if [ -f "$p" ]; then OPENIV_EXE="$p"; log_ok "Found: $p"; return 0; fi
    done

    local found
    found=$(find "$PREFIX_DIR/drive_c" -maxdepth 4 -name "OpenIV*.exe" -type f 2>/dev/null | head -1 || true)
    if [ -n "$found" ]; then OPENIV_EXE="$found"; log_ok "Found: $found"; return 0; fi

    log_warn "OpenIV executable not found"
    return 1
}

# ── 9. Launcher Script & Desktop Entry ────────────────────────────────────────
create_launchers() {
    log_header "Desktop Integration"

    local desktop_dir="${XDG_DATA_HOME}/applications"
    local icons_dir="${XDG_DATA_HOME}/icons"
    mkdir -p "$desktop_dir" "$icons_dir"

    local icon_path="$icons_dir/openiv.png"
    local desktop_file="$desktop_dir/openiv.desktop"
    local wrapper_script="$DATA_DIR/run-openiv.sh"

    # Icon
    if [ -n "$APPDIR" ] && [ -f "$APPDIR/openiv.png" ]; then
        cp "$APPDIR/openiv.png" "$icon_path"
    elif [ ! -f "$icon_path" ]; then
        printf '\211PNG\r\n\032\n\000\000\000\rIHDR\000\000\000\001\000\000\000\001\010\002\000\000\000\220wS\336\000\000\000\022IDATx\234c\370\017\000\000\001\001\001\002\370\217\374\351\000\000\000\000IEND\246B`\202' > "$icon_path"
    fi

    # Wrapper – sources the portable Wine environment
    cat > "$wrapper_script" << WRAPEOF
#!/bin/bash
# OpenIV launcher – generated by OpenIVLinuxInstaller
export WINEPREFIX="$PREFIX_DIR"
export WINEARCH="win64"
export WINEDEBUG="${WINEDEBUG:--all}"
export PATH="$WINE_DIR/bin:\$PATH"
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
    [ -f "$HOME/.bashrc" ] && shell_rc="$HOME/.bashrc"
    [ -z "$shell_rc" ] && [ -f "$HOME/.zshrc" ] && shell_rc="$HOME/.zshrc"
    if [ -n "$shell_rc" ] && ! grep -q "alias openiv=" "$shell_rc" 2>/dev/null; then
        { echo ""; echo "# OpenIV launcher (portable Wine)"; echo "alias openiv='$wrapper_script \"$OPENIV_EXE\"'"; } >> "$shell_rc"
        log_ok "Added 'openiv' alias to $shell_rc"
    fi
}

# ── 10. Summary & Launch ──────────────────────────────────────────────────────
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
    export WINEPREFIX="$PREFIX_DIR" WINEARCH="win64" WINEDEBUG="${WINEDEBUG:--all}"
    PATH="$WINE_DIR/bin:$PATH"
    exec "$WINE_BINARY" "$OPENIV_EXE"
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║${NC}          ${BOLD}OpenIV Linux Installer${NC}                          ${CYAN}║${NC}"
    if [ -n "$APPDIR" ]; then
    echo -e "${CYAN}  ║${NC}          ${GREEN}[AppImage mode – bundled Wine + pre-baked prefix]${NC} ${CYAN}║${NC}"
    else
    echo -e "${CYAN}  ║${NC}          ${YELLOW}[Standalone mode – will download Wine if needed]${NC}   ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    setup_directories
    ensure_wine
    [ -z "$APPDIR" ] && ensure_winetricks   # winetricks only needed for standalone build
    ensure_prefix
    download_openiv_installer
    install_openiv_silent
    detect_gta_v

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
