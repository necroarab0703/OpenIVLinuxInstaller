# Changelog

## v2.0.0 (2026-05-18)

**Complete refactor** — rootless, zero-input, portable Wine runtime.

### Breaking changes
- All paths moved from `~/.OpenIV/` → `~/.local/share/openiv-linux/`
- Wine prefix now at `~/.local/share/openiv-linux/prefix/`

### Added
- **Portable Wine runtime**: downloads Kron4ek Wine 11.9 staging to `~/.local/share/openiv-linux/wine-runtime/` — no system Wine required
- **Zero user interaction**: all `read` prompts, menus, and confirmations removed
- **set -euo pipefail** strict mode throughout; non-critical pipes protected with `|| true`
- **GTA V auto-detection**: scans Steam library folders (including `libraryfolders.vdf`), Proton compatdata, Heroic Games Launcher, and Lutris paths; symlinks to `C:\GTA5`
- **Winetricks auto-download**: fetches winetricks locally if not available system-wide
- **AppImage bundling support**: if the Wine tarball is present inside the AppDir, it's extracted locally without network

### Removed
- All `sudo` / package-manager calls (`apt`, `pacman`, `dnf`, `zypper`, etc.)
- Interactive installer-type choices (download vs. provide file, prefix reuse, launch confirmation)
- Distro-detection (`/etc/os-release`) — no longer needed since no system packages are installed

### Changed
- `setup_wine_prefix` → `create_wine_prefix`: uses `$WINEBOOT` from portable runtime, sets `WINEDLLOVERRIDES`, no longer calls `winetricks win10` on every run
- `download_openiv` → `download_openiv_installer + install_openiv_silent`: splits download from install; installer runs with `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-`
- `create_desktop_entry` → `create_launchers`: launcher scripts now hardcode `PATH` to portable Wine binaries instead of relying on `/usr/bin/wine`
- `launch_openiv` no longer prompts; calls `exec` with portable Wine
- AppRun passes through to installer script directly (idempotent)

## v1.0.0 (2026-05-18)

- Initial release
- Automatic Wine setup and OpenIV installation
- AppImage and shell script distribution
- Desktop entry and terminal alias creation
- Multi-distro support (Arch, Fedora, Debian/Ubuntu, openSUSE, and more)
