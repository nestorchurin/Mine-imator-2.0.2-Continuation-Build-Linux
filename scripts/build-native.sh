#!/usr/bin/env bash
# =============================================================================
# Mine-imator native Linux build tool
# Compiles CppProject directly on the host (no Flatpak sandbox).
#
# Usage:
#   ./scripts/build-native.sh               # build only
#   ./scripts/build-native.sh --install     # build + install to ~/.local
#   ./scripts/build-native.sh --codegen     # also regenerate C++ from GML first
#   ./scripts/build-native.sh --clean       # wipe build dir and rebuild
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build-native"
INSTALL_DIR="$HOME/.local/bin/Mine-imator"
LOG_DIR="$REPO_ROOT/Logs"
LOG="$LOG_DIR/build-native-$(date +%Y%m%d-%H%M%S).log"
JOBS="$(nproc)"

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}▶ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✗ $*${RESET}" >&2; }
step()    { echo -e "\n${BOLD}── $* ──────────────────────────────────${RESET}"; }

# ── parse args ────────────────────────────────────────────────────────────────
DO_INSTALL=false
DO_CODEGEN=false
DO_CLEAN=false
for arg in "$@"; do
    case "$arg" in
        --install)  DO_INSTALL=true ;;
        --codegen)  DO_CODEGEN=true ;;
        --clean)    DO_CLEAN=true ;;
        --help|-h)
            echo "Usage: $0 [--install] [--codegen] [--clean]"
            echo "  --install   Copy binary + datafiles to $INSTALL_DIR"
            echo "  --codegen   Regenerate CppProject/Generated/ from GML (needs dotnet)"
            echo "  --clean     Wipe build-native/ before building"
            exit 0 ;;
        *) error "Unknown argument: $arg"; exit 1 ;;
    esac
done

mkdir -p "$LOG_DIR"

# ── check system deps ────────────────────────────────────────────────────────
step "Checking dependencies"

MISSING_PKGS=()
check_pkg() {
    if ! pkg-config --exists "$1" 2>/dev/null; then
        MISSING_PKGS+=("$2")
    fi
}
check_pkg Qt5Widgets      "qtbase5-dev qt5-qmake"
check_pkg openal          "libopenal-dev"
check_pkg libzip          "libzip-dev"
check_pkg freetype2       "libfreetype6-dev"
check_pkg libavcodec      "libavcodec-dev"
check_pkg libavformat     "libavformat-dev"
check_pkg libavutil       "libavutil-dev"
check_pkg libswresample   "libswresample-dev"
check_pkg libswscale      "libswscale-dev"
check_pkg zlib            "zlib1g-dev"

for t in ninja cmake g++; do
    if ! command -v "$t" &>/dev/null; then
        case "$t" in
            ninja)  MISSING_PKGS+=("ninja-build") ;;
            cmake)  MISSING_PKGS+=("cmake") ;;
            g++)    MISSING_PKGS+=("g++") ;;
        esac
    fi
done

if (( ${#MISSING_PKGS[@]} > 0 )); then
    warn "Missing packages: ${MISSING_PKGS[*]}"
    read -rp "Install them now with sudo apt? [Y/n] " REPLY
    if [[ "${REPLY,,}" != "n" ]]; then
        sudo apt-get install -y "${MISSING_PKGS[@]}"
    else
        error "Cannot build without required packages"
        exit 1
    fi
fi
success "All dependencies present"

# ── codegen (optional) ───────────────────────────────────────────────────────
if [[ "$DO_CODEGEN" == "true" ]]; then
    step "Regenerating C++ from GML (CppGen)"

    if ! command -v dotnet &>/dev/null; then
        error "dotnet not found — needed for --codegen"
        error "Install: https://learn.microsoft.com/dotnet/core/install/linux"
        exit 1
    fi

    CPPGEN_DIR="$REPO_ROOT/CppGen"
    info "Building CppGen..."
    dotnet build "$CPPGEN_DIR/CppGen/CppGen.csproj" -c Release \
        --nologo -v minimal 2>&1 | tee -a "$LOG"

    CPPGEN_BIN="$CPPGEN_DIR/CppGen/bin/Release/net"*"/CppGen"
    # shellcheck disable=SC2086
    CPPGEN_BIN="$(ls $CPPGEN_BIN 2>/dev/null | head -1)"
    if [[ -z "$CPPGEN_BIN" ]]; then
        # Try the dll entrypoint
        CPPGEN_BIN="$(ls "$CPPGEN_DIR/CppGen/bin/Release/"net*"/CppGen.dll" 2>/dev/null | head -1)"
        if [[ -n "$CPPGEN_BIN" ]]; then
            CPPGEN_BIN="dotnet $CPPGEN_BIN"
        fi
    fi
    if [[ -z "$CPPGEN_BIN" ]]; then
        error "CppGen binary not found after build"
        exit 1
    fi

    info "Running CppGen..."
    cd "$REPO_ROOT"
    $CPPGEN_BIN 2>&1 | tee -a "$LOG"
    success "Code generation complete"
fi

# ── clean ────────────────────────────────────────────────────────────────────
if [[ "$DO_CLEAN" == "true" && -d "$BUILD_DIR" ]]; then
    step "Cleaning build directory"
    rm -rf "$BUILD_DIR"
    success "Cleaned $BUILD_DIR"
fi

# ── cmake configure ───────────────────────────────────────────────────────────
step "CMake configure"
mkdir -p "$BUILD_DIR"

cmake -S "$REPO_ROOT/CppProject" -B "$BUILD_DIR" \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DUSE_SYSTEM_LIBS=ON \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    2>&1 | tee -a "$LOG"

success "Configure done"

# ── build ────────────────────────────────────────────────────────────────────
step "Building ($JOBS parallel jobs)"
info "Log: $LOG"

cmake --build "$BUILD_DIR" --parallel "$JOBS" 2>&1 | tee -a "$LOG"

BINARY="$BUILD_DIR/Mine-imator"
if [[ ! -f "$BINARY" ]]; then
    error "Build failed — binary not found at $BINARY"
    error "See: $LOG"
    exit 1
fi

success "Built: $BINARY"

# ── install ──────────────────────────────────────────────────────────────────
if [[ "$DO_INSTALL" == "true" ]]; then
    step "Installing to $INSTALL_DIR"

    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    cp "$BINARY" "$INSTALL_DIR/Mine-imator"
    cp -a "$REPO_ROOT/GmProject/datafiles/." "$INSTALL_DIR/"

    # Create launcher script
    LAUNCHER="$HOME/.local/bin/mine-imator"
    cat > "$LAUNCHER" <<'SCRIPT'
#!/usr/bin/env bash
# Force XWayland (xcb) so QCursor::setPos() works for camera drag.
# On native Wayland, Qt's setPos() is a no-op which breaks the camera.
if [[ -n "$WAYLAND_DISPLAY" && -n "$DISPLAY" ]]; then
    export QT_QPA_PLATFORM=xcb
fi
cd "$(dirname "$(readlink -f "$0")")/Mine-imator"
exec ./Mine-imator "$@"
SCRIPT
    chmod +x "$LAUNCHER"

    # Desktop entry
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    ICON_SRC="$REPO_ROOT/Installer/Linux/Mine-imator/usr/share/pixmaps/mine-imator.png"
    ICON_DST="$HOME/.local/share/pixmaps/mine-imator.png"
    mkdir -p "$HOME/.local/share/pixmaps"
    [[ -f "$ICON_SRC" ]] && cp "$ICON_SRC" "$ICON_DST"

    cat > "$DESKTOP_DIR/mine-imator-native.desktop" <<DESKTOP
[Desktop Entry]
Name=Mine-imator (native)
Comment=3D movie maker for Minecraft
Exec=$LAUNCHER %F
Icon=$ICON_DST
Type=Application
Categories=Graphics;3DGraphics;
StartupWMClass=Mine-imator
DESKTOP

    success "Installed to $INSTALL_DIR"
    success "Launcher: $LAUNCHER"
    success "Run with:  mine-imator"
    echo ""
    info "To remove: rm -rf $INSTALL_DIR $LAUNCHER $DESKTOP_DIR/mine-imator-native.desktop"
else
    echo ""
    success "Build complete: $BINARY"
    info "Run with:  $BINARY"
    info "To install: $0 --install"
fi
