# Changelog

## 2026-06-02

### Added
- Flatpak packaging files:
  - `flatpak/io.github.nestorchurin.MineImator.yml`
  - `flatpak/io.github.nestorchurin.MineImator.desktop`
  - `flatpak/io.github.nestorchurin.MineImator.metainfo.xml`
  - `flatpak/mine-imator.sh`
- Root Flathub manifest:
  - `io.github.nestorchurin.MineImator.yml`
- Flathub submission helper files:
  - `flathub.json` (limit builds to `x86_64`)
  - `FLATHUB_SUBMISSION.md` (submission checklist and commands)
- Linux Flatpak build instructions in `README.md`.
- Linux fork maintainer note in `README.md` with official Mine-imator site and maintainer links.

### Changed
- Updated `CppProject/CMakeLists.txt` for better Linux portability:
  - Added fallback from hardcoded `clang-12` to detected `clang/clang++`.
  - Added `USE_SYSTEM_LIBS` CMake option to link against system media/archive/audio libraries.
  - Added Qt lookup fallback to system Qt when custom `DEV_DIR` Qt build is unavailable.
  - Made Linux `DEV_DIR` configurable through environment variable `DEV_DIR`.
- Updated Flatpak metainfo maintainer and project metadata:
  - Marked package as a community Linux fork.
  - Set homepage to official Mine-imator website.
  - Added maintainer contact URL and maintainer name.
  - Added screenshots for Flathub metadata quality checks.
