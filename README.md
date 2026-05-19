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

<!-- v4 is AppImage-only — standalone mode and one-liner removed -->

## Architecture

### AppImage Mode (`$APPDIR` is set)

| Component | Source | Location in AppImage |
|-----------|--------|---------------------|
| Wine runtime | Pre-bundled (Kron4ek 11.9 staging) | `usr/share/openiv/wine/` |
| Wine prefix with .NET 4.8, VC++, D3D | Pre-baked at build time | `usr/share/openiv/prefix.tar.xz` |
| OpenIV installer | Bundled from official OpenIVSetup.exe | `usr/share/openiv/OpenIVSetup.exe` |

**First run:** extracts prefix tarball (~3 seconds) → installs OpenIV → launches.  
**Subsequent runs:** skips all setup, launches OpenIV immediately.

## System Requirements

- **Linux x86_64**
- **~600 MB disk** (one-time; prefix extracted to `~/.local/share/openiv-linux/`)

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
