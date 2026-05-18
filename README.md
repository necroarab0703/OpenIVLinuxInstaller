# OpenIV Linux Installer

Run **OpenIV** — the ultimate modding tool for GTA V, GTA IV, and Max Payne 3 — on Linux through Wine. No manual Wine configuration needed.

## Quick Start

### Option 1: AppImage (easiest)
```bash
chmod +x OpenIV-x86_64.AppImage
./OpenIV-x86_64.AppImage
```

### Option 2: Shell script
```bash
chmod +x OpenIVLinuxInstaller.sh
./OpenIVLinuxInstaller.sh
```

### Option 3: One-liner
```bash
curl -sSL https://raw.githubusercontent.com/USER/OpenIVLinuxInstaller/main/OpenIVScripts/OpenIVLinuxInstaller.sh | bash
```

## What It Does

The installer automates everything:

1. **Detects** your Linux distribution
2. **Installs Wine and dependencies** if missing (winetricks, curl, etc.)
3. **Creates a Wine prefix** configured for Windows 10
4. **Installs .NET Framework 4.8** (required by OpenIV)
5. **Downloads and installs OpenIV** (or lets you provide your own installer)
6. **Creates a desktop entry** so you can launch OpenIV from your app menu
7. **Adds `openiv` command** to your terminal

## System Requirements

- **Linux** (x86_64) — Arch, Fedora, Debian/Ubuntu, openSUSE, and many more
- **~2 GB free disk space** (for Wine prefix and .NET Framework)
- **Internet connection** (for downloading Wine components and OpenIV)

## Manual Launch

After installation, you can launch OpenIV anytime with:
```bash
openiv
```

Or from the terminal directly:
```bash
export WINEPREFIX="$HOME/.OpenIV/prefix"
wine "$HOME/.OpenIV/prefix/drive_c/Program Files/OpenIV/OpenIV.exe"
```

## Uninstall

```bash
rm -rf "$HOME/.OpenIV"
rm -f "$HOME/.local/share/applications/openiv.desktop"
```

Remove the `alias openiv=...` line from your `~/.bashrc` or `~/.zshrc` if present.

## Build AppImage Locally

```bash
# Install appimagetool
# https://github.com/AppImage/AppImageKit/releases

# Create AppDir
mkdir -p Build/AppDir
cp OpenIVScripts/OpenIVLinuxInstaller.sh Build/AppDir/
cp AppImage/AppRun Build/AppDir/
cp AppImage/openiv.desktop Build/AppDir/
cp AppImage/openiv.png Build/AppDir/

# Build AppImage
ARCH=x86_64 appimagetool Build/AppDir OpenIV-x86_64.AppImage
```

## Known Issues

- .NET Framework 4.8 installation takes 10-15 minutes
- First Wine prefix creation may be slow
- Some GTA mod features may need additional Wine configuration
- AMD/Intel GPU users may experience graphical issues (use `winetricks renderer=vulkan`)

## License

This project provides installation scripts for running OpenIV on Linux. OpenIV is a product of OpenIV Team. All trademarks belong to their respective owners.

## Credits

Inspired by [AffinityOnLinux](https://github.com/ryzendew/Linux-Affinity-Installer).
