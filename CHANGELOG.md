# Changelog

## v3.0.0 (2026-05-19)

**Architectural rewrite** — pre-bundled Wine + pre-baked prefix, OpenIV SSL fallback chain.

### Added
- **Pre-baked Wine prefix**: `.NET 4.8, VC++ 2019, D3DX11.43, corefonts` are installed at build time by `build-wine-prefix.sh` and bundled as `prefix.tar.xz` inside the AppImage. First-run extraction: ~3 seconds.
- **Bundled Wine runtime**: Kron4ek Wine 11.9 staging binaries are copied directly into `usr/share/openiv/wine/` inside the AppImage. No network download at runtime.
- **OpenIV multi-tier fallback download**:
  - Tier 1: `openiv.com` (normal SSL)
  - Tier 1b: `openiv.com` (with `--insecure` / `--no-check-certificate`)
  - Tier 2: `gta5-mods.com` page scraping for mirror link
  - Tier 2b: gta5-mods.com with SSL bypass
  - Tier 3: clear error with manual download instructions
- **`docs/BUILDING.md`** — full build documentation including CI workflow details
- **GitHub Actions cache** for `prefix.tar.xz` (keyed on build-wine-prefix.sh hash)

### Changed
- `OpenIVLinuxInstaller.sh`:
  - Detects AppImage mode (`$APPDIR`) and uses bundled Wine + prefix tarball
  - Falls back to dynamic download + winetricks build when running standalone
  - `download_with_fallback()` function replaces simple `silent_download()` for OpenIV
  - `ensure_wine()` checks bundled path first, then cached local, then downloads
  - `ensure_prefix()` extracts pre-baked tarball or builds from scratch
  - `ensure_winetricks()` only called in standalone mode
- `build-appimage.sh`: runs `build-wine-prefix.sh` first, copies Wine + prefix tarball into AppDir
- CI workflow: installs `winetricks`, `cabextract` for prefix build; caches prefix tarball

### Removed
- Runtime winetricks calls for .NET/VC++/D3D/fonts in AppImage mode (now pre-baked)
- Silent download of Wine at runtime in AppImage mode (now pre-bundled)

## v2.0.0 (2026-05-18)

- Rootless, zero-input, portable Wine runtime
- GTA V auto-detection
- OpenIV installer download
- Desktop integration

## v1.0.0 (2026-05-18)

- Initial release
