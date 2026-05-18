#!/bin/bash
################################################################################
# OpenIV Linux Installer - All-in-One Installation Script
# Automatically sets up Wine and installs OpenIV on Linux
# Usage: chmod +x OpenIVLinuxInstaller.sh && ./OpenIVLinuxInstaller.sh
################################################################################

if [ ! -x "$(readlink -f "$0")" ]; then
    chmod +x "$(readlink -f "$0")"
fi

if [ -z "$BASH_VERSION" ]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    else
        echo "This script must be run with bash" >&2
        exit 1
    fi
fi

OPENIV_DIR="$HOME/.OpenIV"
OPENIV_PREFIX="$OPENIV_DIR/prefix"
WINE_BINARY="wine"
WINEARCH="win64"
WINEDEBUG="-all"

if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; NC=''
fi

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_progress() { echo -e "${GREEN}  →${NC} $1"; }

download_file() {
    local url=$1 output=$2 description=$3
    print_progress "Downloading $description..."
    if command -v curl &> /dev/null; then
        if curl -# -L "$url" -o "$output"; then return 0; fi
    fi
    if command -v wget &> /dev/null; then
        if wget --progress=bar:force:noscroll "$url" -O "$output" 2>/dev/null; then return 0; fi
    fi
    print_error "Failed to download $description"
    return 1
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    else
        print_error "Could not detect Linux distribution"
        exit 1
    fi
}

check_dependencies() {
    print_header "Dependency Verification"

    local missing_deps=""
    for dep in wine winetricks wget curl 7z tar jq; do
        print_progress "Checking for $dep..."
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+="$dep "
        else
            print_success "$dep is installed"
        fi
    done

    if ! command -v unzstd &> /dev/null && ! command -v zstd &> /dev/null; then
        missing_deps+="zstd "
        print_error "zstd or unzstd is not installed"
    else
        print_success "zstd support is available"
    fi

    if [ -n "$missing_deps" ]; then
        print_warning "Missing dependencies: $missing_deps"
        install_dependencies
    else
        print_success "All required dependencies are installed!"
    fi
    echo ""
}

install_dependencies() {
    print_step "Installing dependencies for $DISTRO..."
    case $DISTRO in
        "arch"|"cachyos"|"endeavouros"|"xerolinux"|"manjaro"|"artix")
            sudo pacman -S --needed wine winetricks wget curl p7zip tar jq zstd
            ;;
        "fedora"|"nobara")
            sudo dnf install -y wine winetricks wget curl p7zip p7zip-plugins tar jq zstd
            ;;
        "opensuse-tumbleweed"|"opensuse-leap"|"suse")
            sudo zypper install -y wine winetricks wget curl p7zip tar jq zstd
            ;;
        "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary"|"zorin"|"pikaos"|"kali"|"parrot")
            sudo dpkg --add-architecture i386
            sudo apt update
            sudo apt install -y wine wine64 wine32 winetricks wget curl p7zip-full p7zip tar jq zstd
            ;;
        "void")
            sudo xbps-install -S wine winetricks wget curl p7zip tar jq zstd
            ;;
        "solus")
            sudo eopkg install wine winetricks wget curl p7zip tar jq zstd
            ;;
        "gentoo"|"calculate")
            sudo emerge --ask=n sys-apps/util-linux app-emulation/wine app-emulation/winetricks net-misc/wget net-misc/curl app-arch/p7zip app-arch/tar app-misc/jq app-arch/zstd
            ;;
        "nixos")
            print_info "On NixOS, please add these to your configuration.nix:"
            print_info "  programs.wine.enable = true;"
            print_info "  programs.winetricks.enable = true;"
            print_info "  environment.systemPackages = [ wget curl p7zip jq zstd ];"
            print_info "Then run: sudo nixos-rebuild switch"
            echo ""
            print_warning "Cannot auto-install on NixOS. Please install dependencies manually."
            exit 1
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            print_info "Please install the following packages manually:"
            print_info "wine winetricks wget curl p7zip tar jq zstd"
            exit 1
            ;;
    esac
    print_success "All dependencies installed!"
    echo ""
}

cleanup_wine() {
    print_step "Stopping any running Wine processes..."
    WINEPREFIX="$OPENIV_PREFIX" wineserver -k 2>/dev/null || true
    sleep 1
    print_success "Wine processes stopped"
}

setup_wine_prefix() {
    print_header "Wine Prefix Setup"

    mkdir -p "$OPENIV_DIR"

    cleanup_wine

    print_step "Creating Wine prefix at $OPENIV_PREFIX..."
    export WINEPREFIX="$OPENIV_PREFIX"
    export WINEARCH="win64"

    print_progress "Running wineboot (initializing Wine prefix)..."
    wineboot -u 2>/dev/null || true

    if [ ! -d "$OPENIV_PREFIX/drive_c" ]; then
        print_error "Wine prefix creation failed"
        exit 1
    fi
    print_success "Wine prefix created successfully"

    print_step "Setting Windows version to Windows 10..."
    winetricks --unattended --force --no-isolate --optout win10 2>/dev/null || true
    print_success "Windows 10 compatibility set"

    print_step "Installing .NET Framework 4.8 (this may take 10-15 minutes)..."
    print_info "OpenIV requires .NET Framework 4.8 to run. Please be patient."
    winetricks --unattended --force --no-isolate --optout dotnet48 2>/dev/null || true
    print_success ".NET Framework 4.8 installation completed"

    print_step "Installing core fonts..."
    winetricks --unattended --force --no-isolate --optout corefonts 2>/dev/null || true
    print_success "Core fonts installed"

    print_step "Installing Visual C++ Redistributables..."
    winetricks --unattended --force --no-isolate --optout vcrun2022 2>/dev/null || true
    print_success "VC++ Redistributables installed"

    print_info "Wine prefix setup complete!"
    echo ""
}

download_openiv() {
    print_header "OpenIV Download"

    mkdir -p "$OPENIV_DIR/downloads"

    local installer_path="$OPENIV_DIR/downloads/ovisetup.exe"

    if [ -f "$installer_path" ] && [ -s "$installer_path" ]; then
        print_info "OpenIV installer already downloaded"
        echo "$installer_path"
        return 0
    fi

    print_info "OpenIV is the ultimate modding tool for GTA V, GTA IV, and Max Payne 3."
    echo ""

    while true; do
        echo -e "  ${GREEN}1.${NC} Download OpenIV installer from official website (recommended)"
        echo -e "  ${GREEN}2.${NC} Provide your own OpenIV installer file"
        echo ""
        echo -n -e "${BOLD}Select an option (1 or 2): ${NC}"
        read -r choice
        echo ""

        case $choice in
            1)
                print_step "Downloading OpenIV installer from openiv.com..."
                print_info "URL: https://openiv.com/webiv/guest.php?get=0"
                echo ""

                if wget --progress=bar:force:noscroll "https://openiv.com/webiv/guest.php?get=0" -O "$installer_path" 2>/dev/null; then
                    if [ -s "$installer_path" ]; then
                        print_success "OpenIV installer downloaded successfully!"
                        echo "$installer_path"
                        return 0
                    fi
                fi

                if command -v curl &> /dev/null; then
                    if curl -# -L "https://openiv.com/webiv/guest.php?get=0" -o "$installer_path"; then
                        if [ -s "$installer_path" ]; then
                            print_success "OpenIV installer downloaded successfully!"
                            echo "$installer_path"
                            return 0
                        fi
                    fi
                fi

                print_error "Automatic download failed. The file may be behind a redirect."
                print_info "Please download manually from: https://openiv.com/"
                echo ""
                ;;
            2)
                print_step "Please provide the path to your OpenIV installer (.exe):"
                echo -n -e "${BOLD}Path: ${NC}"
                read -r user_path
                user_path=$(echo "$user_path" | tr -d '"' | xargs)

                if [ -f "$user_path" ] && [ -r "$user_path" ]; then
                    cp "$user_path" "$installer_path"
                    print_success "Installer copied to $installer_path"
                    echo "$installer_path"
                    return 0
                else
                    print_error "File not found or not readable: $user_path"
                    echo ""
                    continue
                fi
                ;;
            *)
                print_error "Invalid option. Please select 1 or 2."
                echo ""
                ;;
        esac
    done
}

install_openiv() {
    local installer_path=$1
    print_header "OpenIV Installation"

    export WINEPREFIX="$OPENIV_PREFIX"

    print_step "Running OpenIV installer in Wine..."
    print_info "Follow the installer wizard to complete installation."
    print_info "Default installation path is recommended."
    echo ""

    wine "$installer_path"

    echo ""
    print_success "OpenIV installation process completed"
}

verify_installation() {
    print_header "Installation Verification"

    export WINEPREFIX="$OPENIV_PREFIX"

    local found_exe=""
    local search_paths=(
        "$OPENIV_PREFIX/drive_c/Program Files/OpenIV/OpenIV.exe"
        "$OPENIV_PREFIX/drive_c/Program Files (x86)/OpenIV/OpenIV.exe"
        "$OPENIV_PREFIX/drive_c/Program Files/OpenIV/OpenIV Launcher.exe"
        "$OPENIV_PREFIX/drive_c/Program Files (x86)/OpenIV/OpenIV Launcher.exe"
    )

    for path in "${search_paths[@]}"; do
        if [ -f "$path" ]; then
            found_exe="$path"
            break
        fi
    done

    if [ -z "$found_exe" ]; then
        print_warning "OpenIV executable not found at standard locations."
        print_info "Searching for OpenIV executable in prefix..."
        found_exe=$(find "$OPENIV_PREFIX/drive_c" -name "OpenIV*.exe" -type f 2>/dev/null | head -1)
    fi

    if [ -n "$found_exe" ]; then
        print_success "OpenIV found at: $found_exe"
        OPENIV_EXE="$found_exe"
        return 0
    else
        print_warning "OpenIV executable not found."
        print_info "You can manually specify the path to OpenIV.exe later."
        return 1
    fi
}

create_desktop_entry() {
    local exe_path=$1
    print_header "Desktop Integration"

    export WINEPREFIX="$OPENIV_PREFIX"

    local desktop_dir="$HOME/.local/share/applications"
    local icons_dir="$HOME/.local/share/icons"
    mkdir -p "$desktop_dir" "$icons_dir"

    local icon_path="$icons_dir/openiv.png"
    local desktop_file="$desktop_dir/openiv.desktop"

    local script_dir
    local wrapper_script="$OPENIV_DIR/run-openiv.sh"

    cat > "$wrapper_script" << 'WRAPEOF'
#!/bin/bash
export WINEPREFIX="$HOME/.OpenIV/prefix"
export WINEDEBUG="-all"

if command -v gamescope &> /dev/null; then
    gamescope -f -- wine "$HOME/.OpenIV/prefix/drive_c/Program Files/OpenIV/OpenIV.exe" 2>/dev/null || \
    gamescope -f -- wine "$HOME/.OpenIV/prefix/drive_c/Program Files (x86)/OpenIV/OpenIV.exe" 2>/dev/null || \
    gamescope -f -- wine "$HOME/.OpenIV/prefix/drive_c/Program Files/OpenIV/OpenIV Launcher.exe" 2>/dev/null || \
    gamescope -f -- wine "$HOME/.OpenIV/prefix/drive_c/Program Files (x86)/OpenIV/OpenIV Launcher.exe" 2>/dev/null
else
    wine "$HOME/.OpenIV/prefix/drive_c/Program Files/OpenIV/OpenIV.exe" 2>/dev/null || \
    wine "$HOME/.OpenIV/prefix/drive_c/Program Files (x86)/OpenIV/OpenIV.exe" 2>/dev/null || \
    wine "$HOME/.OpenIV/prefix/drive_c/Program Files/OpenIV/OpenIV Launcher.exe" 2>/dev/null || \
    wine "$HOME/.OpenIV/prefix/drive_c/Program Files (x86)/OpenIV/OpenIV Launcher.exe" 2>/dev/null
fi
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
    print_success "Desktop entry created at $desktop_file"

    print_info "You can now launch OpenIV from your application menu."
    echo ""
}

launch_openiv() {
    print_header "Launch OpenIV"

    export WINEPREFIX="$OPENIV_PREFIX"

    echo -e "${GREEN}OpenIV is ready to launch!${NC}"
    echo ""
    echo -e "  ${BOLD}Options:${NC}"
    echo -e "  ${GREEN}1.${NC} Launch OpenIV now"
    echo -e "  ${GREEN}2.${NC} Exit (you can run '${CYAN}openiv${NC}' later from terminal)"
    echo ""
    echo -n -e "${BOLD}Select an option (1 or 2): ${NC}"
    read -r launch_choice

    case $launch_choice in
        1)
            print_step "Launching OpenIV..."
            echo ""

            local try_paths=(
                "$OPENIV_PREFIX/drive_c/Program Files/OpenIV/OpenIV.exe"
                "$OPENIV_PREFIX/drive_c/Program Files (x86)/OpenIV/OpenIV.exe"
                "$OPENIV_PREFIX/drive_c/Program Files/OpenIV/OpenIV Launcher.exe"
                "$OPENIV_PREFIX/drive_c/Program Files (x86)/OpenIV/OpenIV Launcher.exe"
            )

            local launched=false
            for exe in "${try_paths[@]}"; do
                if [ -f "$exe" ]; then
                    print_info "Starting: $exe"
                    wine "$exe"
                    launched=true
                    break
                fi
            done

            if [ "$launched" = false ]; then
                print_error "Could not find OpenIV executable to launch."
                print_info "Try running manually: wine /path/to/OpenIV.exe"
            fi
            ;;
        2)
            print_info "Exiting. To launch OpenIV later:"
            echo ""
            echo -e "  ${CYAN}export WINEPREFIX=\"$OPENIV_PREFIX\"${NC}"
            echo -e "  ${CYAN}wine \"$OPENIV_PREFIX/drive_c/Program Files/OpenIV/OpenIV.exe\"${NC}"
            echo ""
            print_info "Or use the desktop shortcut that was created."
            ;;
    esac
}

install_shell_command() {
    local wrapper_script="$OPENIV_DIR/run-openiv.sh"

    if [ -f "$wrapper_script" ]; then
        local bashrc="$HOME/.bashrc"
        local zshrc="$HOME/.zshrc"
        local profile_files=("$bashrc" "$zshrc")

        for rc in "${profile_files[@]}"; do
            if [ -f "$rc" ]; then
                if ! grep -q "alias openiv=" "$rc" 2>/dev/null; then
                    echo "" >> "$rc"
                    echo "# OpenIV alias" >> "$rc"
                    echo "alias openiv='$wrapper_script'" >> "$rc"
                    print_info "Added 'openiv' alias to $rc"
                fi
            fi
        done

        echo ""
        print_success "You can now run '${CYAN}openiv${NC}' from terminal!"
        print_info "Or launch OpenIV from your application menu."
    fi
}

print_banner() {
    clear
    echo ""
    echo -e "${CYAN}  ╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}  ║${NC}                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}           ${BOLD}OpenIV Linux Installer${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  ${GREEN}Run OpenIV on Linux with Wine${NC}                          ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}  Automatic setup - no manual Wine configuration needed${NC}       ${CYAN}║${NC}"
    echo -e "${CYAN}  ║${NC}                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}  ╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_summary() {
    print_header "Installation Complete"

    echo -e "${GREEN}${BOLD}OpenIV has been successfully installed on your system!${NC}"
    echo ""
    echo -e "${BOLD}Key Information:${NC}"
    echo -e "  ${GREEN}•${NC} Wine Prefix: ${CYAN}$OPENIV_PREFIX${NC}"
    echo -e "  ${GREEN}•${NC} OpenIV Location: ${CYAN}$OPENIV_PREFIX/drive_c/Program Files/OpenIV/${NC}"
    echo ""
    echo -e "${BOLD}How to Launch:${NC}"
    echo -e "  ${GREEN}1.${NC} Type ${CYAN}openiv${NC} in your terminal"
    echo -e "  ${GREEN}2.${NC} Find OpenIV in your application menu"
    echo -e "  ${GREEN}3.${NC} Run: ${CYAN}WINEPREFIX=\"$OPENIV_PREFIX\" wine \"$OPENIV_PREFIX/drive_c/Program Files/OpenIV/OpenIV.exe\"${NC}"
    echo ""
    echo -e "${BOLD}Notes:${NC}"
    echo -e "  ${YELLOW}•${NC} First launch may be slower as Wine finalizes setup"
    echo -e "  ${YELLOW}•${NC} To uninstall, delete: ${CYAN}rm -rf $OPENIV_DIR${NC}"
    echo ""
}

main() {
    print_banner

    detect_distro
    print_info "Detected distribution: $DISTRO $VERSION"
    echo ""

    check_dependencies

    if [ -d "$OPENIV_PREFIX/drive_c" ] && [ -f "$OPENIV_PREFIX/drive_c/windows/system32/kernel32.dll" ]; then
        print_info "Wine prefix already exists at $OPENIV_PREFIX"
        echo ""
        echo -e "  ${GREEN}1.${NC} Use existing prefix and check for OpenIV"
        echo -e "  ${GREEN}2.${NC} Recreate Wine prefix (clean install)"
        echo ""
        echo -n -e "${BOLD}Select an option (1 or 2): ${NC}"
        read -r prefix_choice

        if [ "$prefix_choice" = "2" ]; then
            print_warning "Removing existing Wine prefix..."
            rm -rf "$OPENIV_PREFIX"
            setup_wine_prefix
        fi
    else
        setup_wine_prefix
    fi

    installer_path=$(download_openiv)

    if [ -n "$installer_path" ] && [ -f "$installer_path" ]; then
        install_openiv "$installer_path"
    fi

    if verify_installation; then
        create_desktop_entry "$OPENIV_EXE"
        install_shell_command
        print_summary
        launch_openiv
    else
        print_warning "Installation may not be complete."
        echo ""
        echo -e "  ${GREEN}1.${NC} Try to launch anyway"
        echo -e "  ${GREEN}2.${NC} Exit"
        echo ""
        echo -n -e "${BOLD}Select: ${NC}"
        read -r retry_choice

        if [ "$retry_choice" = "1" ]; then
            print_step "Searching for OpenIV executable..."
            local found=$(find "$OPENIV_PREFIX/drive_c" -name "*.exe" -type f 2>/dev/null | grep -i openiv | head -1)
            if [ -n "$found" ]; then
                print_success "Found: $found"
                create_desktop_entry "$found"
                install_shell_command
                print_summary
            fi
            launch_openiv
        fi
    fi
}

main "$@"
