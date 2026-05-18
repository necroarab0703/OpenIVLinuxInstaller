# OpenIV Linux Installer

Run **OpenIV** — the ultimate modding tool for GTA V, GTA IV, and Max Payne 3 — on Linux through a **fully automated, zero-input, self-contained portable Wine** runtime. No manual configuration, no root, no system package changes.

## Quick Start

### AppImage (easiest — fully self-contained)
```bash
chmod +x OpenIV-x86_64.AppImage
./OpenIV-x86_64.AppImage
```

### Shell script
```bash
chmod +x OpenIVLinuxInstaller.sh
./OpenIVLinuxInstaller.sh
```

### One-liner
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/necroarab0703/OpenIVLinuxInstaller/main/OpenIVScripts/OpenIVLinuxInstaller.sh)
```

## How It Works

The script is a **zero-interaction, rootless AppImage wrapper**:

| Step | What happens |
|------|-------------|
| 1 | Downloads a **portable Wine 11.9 staging** build (Kron4ek) to `~/.local/share/openiv-linux/wine-runtime/` |
| 2 | Downloads **winetricks** locally if not available on the system |
| 3 | Creates a **Wine prefix** at `~/.local/share/openiv-linux/prefix/` (Windows 10, no dialogs) |
| 4 | Installs **.NET Framework 4.8, VC++ 2019, and DirectX 11.43** via winetricks (silent) |
| 5 | **Downloads & installs OpenIV** (`/VERYSILENT`, no prompts) |
| 6 | **Auto-detects GTA V** in Steam/Proton/Heroic/Lutris paths and symlinks to `C:\GTA5` |
| 7 | Creates **desktop launcher** + `openiv` terminal alias pointing to portable Wine |

## Key Design Decisions

- **No `sudo` / no root** — never touches `/usr`, never calls `apt`/`pacman`/`dnf`
- **No user prompts** — all `read` / menu / Y-n interaction eliminated
- **Portable Wine runtime** — pre-compiled `x86_64` builds from [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds)
- **set -euo pipefail** — strict error handling, non-critical warnings don't crash
- **Idempotent** — safe to re-run; already-downloaded components are skipped
- **AppImage-ready** — if `wine-*.tar.xz` is bundled inside the AppDir, extraction happens locally without network

## System Requirements

- **Linux x86_64** with **curl** or **wget** (both are ubiquitous)
- **~90 MB** for the portable Wine tarball download
- **~900 MB** disk space after .NET 4.8 installation inside the prefix
- **Internet** for first-run downloads

## Launch Methods

After installation:
```bash
openiv                          # terminal alias
# or from application menu      # "OpenIV" desktop entry
```

## Uninstall

```bash
rm -rf "$HOME/.local/share/openiv-linux"
rm -f "$HOME/.local/share/applications/openiv.desktop"
# Remove "alias openiv=..." from ~/.bashrc / ~/.zshrc if desired
```

## Build AppImage Locally

```bash
# Install appimagetool (https://github.com/AppImage/AppImageKit)
mkdir -p Build/AppDir
cp OpenIVScripts/OpenIVLinuxInstaller.sh Build/AppDir/
cp AppImage/AppRun Build/AppDir/
cp AppImage/openiv.desktop Build/AppDir/
cp AppImage/openiv.png Build/AppDir/

ARCH=x86_64 appimagetool Build/AppDir OpenIV-x86_64.AppImage
```

To bundle Wine inside the AppImage (for fully-offline use), also copy the tarball:
```bash
cp ~/.cache/openiv-linux/wine/wine-11.9-staging-amd64-wow64.tar.xz Build/AppDir/
```

## License

This project provides installation scripts for running OpenIV on Linux. OpenIV is a product of the OpenIV Team. All trademarks belong to their respective owners.

Inspired by [AffinityOnLinux](https://github.com/ryzendew/Linux-Affinity-Installer).
