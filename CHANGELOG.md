# Changelog
## 2026-06-07

### Fixed
- **Keyboard shortcuts broken on Linux** (`CppProject/AppHandler.cpp`):
  - `SetKeyDown()` was passing `event->nativeVirtualKey()` as the GML key code, which returns
    lowercase X11 keysyms (e.g. `97` for 'a') — mismatching GML's `ord('A')=65`-based keybind
    constants. Changed to use `event->key()` which returns uppercase Qt key values matching GML.
- **Keyboard shortcuts broken with non-Latin layouts (Cyrillic, etc.)** (`CppProject/AppHandler.cpp`):
  - `event->key()` returns the layout-specific character (e.g. a Cyrillic code) when a non-Latin
    keyboard layout is active, breaking all letter shortcuts. Added a `scanCodeMap` that maps
    physical X11 scan codes (fixed for standard PC keyboards) to uppercase ASCII, bypassing layout
    entirely. Used as priority lookup before `event->key()` fallback.
- **Mouse drag/wrap broken on Wayland** (`CppProject/AppHandler.cpp`):
  - `QCursor::setPos()` is a silent no-op on the native Wayland platform, making camera drag and
    mouse wrap non-functional. Added a runtime check: if `QGuiApplication::platformName() == "wayland"`,
    `AppWindow::mouseEnableLock` is set to `false` at startup so the delta-tracking code path
    (which does not rely on cursor warping) is used instead.
- **Cursor hitting viewport edge during rotation/pan** (`CppProject/World/Preview.cpp`):
  - During ROTATE and PAN modes in the world importer viewport, the mouse cursor would hit the
    screen edge and stop registering movement. Added Blender-style edge wrap: when the cursor
    reaches within 4px of the viewport edge, it teleports to the opposite side so rotation/pan
    is unlimited.
## 2026-06-07

### Fixed
- **Keyboard shortcuts broken on Linux** (`CppProject/AppHandler.cpp`):
  - `SetKeyDown` previously used `event->nativeVirtualKey()` as the key code fallback for unmapped keys.
    On Linux/X11 this returns the X11 keysym (`XK_a = 97`, `XK_z = 122`, etc.), which does not match
    GameMaker's `ord()`-based VK constants (`ord('A') = 65`, `ord('Z') = 90`).
  - Changed to `event->key()` which returns Qt key enum values — for letter/digit keys these equal
    the uppercase ASCII code, matching GameMaker's VK system exactly.
  - Previously all letter-based shortcuts (Ctrl+Z, Ctrl+S, W/A/S/D navigation, etc.) were silently
    ignored unless Shift was also held.
- **Mouse camera control broken on native Wayland** (`CppProject/AppHandler.cpp`):
  - `QCursor::setPos()` is a no-op on the native Wayland platform; the app uses this for
    mouse-lock/wrap during camera drag (`app_mouse_wrap` → `window_mouse_set` → `display_mouse_set`).
  - Added runtime detection after `QApplication` init: if `QGuiApplication::platformName() == "wayland"`,
    `AppWindow::mouseEnableLock` is set to `false`, enabling the same delta-tracking approach
    used on macOS (no physical cursor warp; virtual mouse position accumulates movement deltas).
  - Added `#include <QGuiApplication>` to `AppHandler.cpp` for the platform name query.
  - Note: when the Flatpak runs under XWayland (`QT_QPA_PLATFORM=xcb`), `mouseEnableLock`
    stays `true` and physical cursor warping continues to work as intended.

## 2026-06-02

### Added
- Flatpak packaging files:
  - `flatpak/com.nestor_churin.MineImator.yml`
  - `flatpak/com.nestor_churin.MineImator.desktop`
  - `flatpak/com.nestor_churin.MineImator.metainfo.xml`
  - `flatpak/mine-imator.sh`
- Root Flathub manifest:
  - `com.nestor_churin.MineImator.yml`
- Local Flathub test manifest:
  - `com.nestor_churin.MineImator.local.yml`
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
  - Added pkg-config system dependencies for `zlib` and `freetype2` in `USE_SYSTEM_LIBS` mode.
- Updated `CppGen` to run on Linux for reproducible code generation:
  - Replaced Windows-style path concatenation with `Path.Combine` in `CppGen/CppGen/Program.cs`, `CppGen/CppGen/Sprite.cs`, and `CppGen/CppGen/Shader.cs`.
  - Removed blocking `Console.ReadKey()` call from generator run flow for non-interactive execution.
  - Disabled interactive shader copy-back prompt in generator run flow to avoid CI/local automation hangs.
- Updated `CppProject/Library/MovieLib.cpp` for FFmpeg ABI compatibility in newer runtimes:
  - Added `AVChannelLayout` based audio channel setup for modern FFmpeg/libavutil.
  - Kept legacy channel fields under version guards for older FFmpeg builds.
- Updated Flatpak packaging to include runtime data files required by the app:
  - Added `cp -a GmProject/datafiles/. /app/bin/` to all Flatpak manifests.
  - Updated `flatpak/mine-imator.sh` to launch from `/app/bin` so relative `Data/*` paths resolve correctly.
  - Added a Wayland session fallback in `flatpak/mine-imator.sh` to prefer Qt `xcb` via XWayland, fixing cursor-position warnings/limitations.
- Updated Flatpak metainfo maintainer and project metadata:
  - Marked package as a community Linux fork.
  - Set homepage to official Mine-imator website.
  - Added maintainer contact URL and maintainer name.
  - Added screenshots for Flathub metadata quality checks.
- Validated local Flathub-style build and install:
  - `flatpak run --command=flathub-build org.flatpak.Builder --install com.nestor_churin.MineImator.local.yml` completed with exit code `0`.
  - Installed artifacts include `com.nestor_churin.MineImator` and `com.nestor_churin.MineImator.Debug` in local repo.
