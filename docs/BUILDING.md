# Building the OpenIV Linux AppImage

This document explains how to build the fully self-contained AppImage from source.

## Prerequisites

- **Linux x86_64**
- **appimagetool** — from [AppImageKit releases](https://github.com/AppImage/AppImageKit/releases)
- **bash**, **curl**/**wget**, **tar**, **xz-utils**
- **winetricks** (for the prefix builder)
- **~5 GB free disk** (for .NET 4.8 installation during prefix build)
- **~25 minutes** (for the prefix build — .NET 4.8 is the bottleneck)

## Quick Build

```bash
# 1. Install appimagetool
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage -O /tmp/appimagetool
chmod +x /tmp/appimagetool

# 2. Run the build script
./build-appimage.sh
```

This will:
1. Run `OpenIVScripts/build-wine-prefix.sh` — downloads Wine, creates prefix, installs .NET, compresses
2. Assemble the AppDir with Wine binaries + prefix tarball + scripts
3. Run appimagetool to produce `Build/OpenIV-x86_64.AppImage`

## Build Steps in Detail

### Step 1: Build the pre-baked prefix

```bash
# Run manually if you want to inspect the process
bash OpenIVScripts/build-wine-prefix.sh
```

Output:
- `build/prefix-builder/wine/` — extracted portable Wine
- `build/prefix.tar.xz` — compressed prefix (with .NET 4.8, VC++ 2019, D3DX11.43, corefonts)

### Step 2: Assemble the AppDir

The AppDir structure is:

```
AppDir/
├── AppRun                         # AppImage entry point
├── OpenIVLinuxInstaller.sh        # Runtime installer
├── openiv.desktop                 # Desktop integration
├── openiv.png                     # Icon
└── usr/share/openiv/
    ├── wine/                      # Portable Wine binaries (Kron4ek)
    │   ├── bin/wine
    │   ├── bin/wineboot
    │   ├── bin/wineserver
    │   ├── lib/
    │   └── share/
    └── prefix.tar.xz              # Pre-baked prefix with .NET 4.8
```

### Step 3: Run appimagetool

```bash
ARCH=x86_64 appimagetool Build/AppDir Build/OpenIV-x86_64.AppImage
```

## CI Build

The GitHub Actions workflow in `.github/workflows/build.yml` automates everything:

1. Triggers on `v*` tags or manual dispatch
2. Caches `build/prefix.tar.xz` between runs (keyed on build-wine-prefix.sh hash)
3. Builds the prefix if not cached
4. Assembles and packages the AppImage
5. Creates a GitHub Release with the AppImage attached

To trigger a CI release:

```bash
git tag v3.0.0
git push origin v3.0.0
```

## Output

- `Build/OpenIV-x86_64.AppImage` — the final self-contained AppImage

## Troubleshooting

| Issue | Likely Cause | Fix |
|-------|-------------|-----|
| .NET install hangs | Wine processes not killed | Kill all wine processes, retry |
| prefix.tar.xz corrupt | Out of disk space | Free 5 GB, delete `build/`, retry |
| appimagetool fails: "file not found" | FUSE not available | Use `--appimage-extract-and-run` flag |
| OpenIV download fails | openiv.com SSL expired | Script auto-falls back to gta5-mods.com |
