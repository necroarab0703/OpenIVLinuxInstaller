# OpenIV Linux Installer

Run **OpenIV** — the ultimate modding tool for GTA V, GTA IV, and Max Payne 3 — on Linux.  
Fully automated, zero user input, no root required.

## Quick Start

### AppImage (recommended — fully self-contained)
```bash
chmod +x OpenIV-x86_64.AppImage
./OpenIV-x86_64.AppImage
```
First run completes in **~3 seconds** for Wine prefix setup — .NET 4.8 is pre-installed inside the AppImage.

### Shell script (standalone mode)
```bash
chmod +x OpenIVLinuxInstaller.sh
./OpenIVLinuxInstaller.sh
```
Standalone mode downloads a portable Wine runtime on first run (10-20 min for .NET install).

### One-liner
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/necroarab0703/OpenIVLinuxInstaller/main/OpenIVScripts/OpenIVLinuxInstaller.sh)
```

## Architecture

### AppImage Mode (`$APPDIR` is set)

| Component | Source | Location in AppImage |
|-----------|--------|---------------------|
| Wine runtime | Pre-bundled (Kron4ek 11.9 staging) | `usr/share/openiv/wine/` |
| Wine prefix with .NET 4.8, VC++, D3D | Pre-baked at build time | `usr/share/openiv/prefix.tar.xz` |
| OpenIV installer | Downloaded at runtime from openiv.com (with fallback mirrors) | `~/.local/share/openiv-linux/downloads/` |

**First run:** extracts prefix tarball (~3 seconds) → downloads OpenIV → installs → launches.  
**Subsequent runs:** skips all setup, launches OpenIV immediately.

### Standalone (`.sh`) Mode

Downloads Wine from Kron4ek, builds prefix from scratch using winetricks (10-20 min), then proceeds as above.

### OpenIV Download Fallback Chain

1. `openiv.com` with normal SSL
2. `openiv.com` with `--insecure` / `--no-check-certificate`
3. `gta5-mods.com/tools/openiv` page scraping
4. gta5-mods.com with SSL bypass
5. Error — user is directed to download manually

## System Requirements

- **Linux x86_64** with **curl** or **wget**
- **AppImage mode:** ~600 MB disk (one-time; prefix extracted to `~/.local/share/openiv-linux/`)
- **Standalone mode:** ~2 GB temporary (for .NET install)

## Launch Methods

```bash
openiv                                   # terminal alias
# or "OpenIV" in your application menu   # desktop entry
```

## Uninstall

```bash
rm -rf "$HOME/.local/share/openiv-linux"
rm -f "$HOME/.local/share/applications/openiv.desktop"
```

## Build From Source

See [BUILDING.md](docs/BUILDING.md) for full build instructions.  
TL;DR: `./build-appimage.sh` (requires appimagetool + ~25 min for prefix build).

## License

Installation scripts. OpenIV is a product of the OpenIV Team. All trademarks belong to their respective owners.

Inspired by [AffinityOnLinux](https://github.com/ryzendew/Linux-Affinity-Installer).
