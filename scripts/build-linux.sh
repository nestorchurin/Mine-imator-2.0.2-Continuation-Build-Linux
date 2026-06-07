#!/usr/bin/env bash
# =============================================================================
# Mine-imator Linux Flatpak build tool
# Usage:
#   ./scripts/build-linux.sh              # build + install locally
#   ./scripts/build-linux.sh --release    # build, install, commit, push,
#                                         # export .flatpak and upload to release
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO_ROOT/com.nestor_churin.MineImator.local.yml"
FLATPAK_REPO="$REPO_ROOT/repo"
LOG_DIR="$REPO_ROOT/Logs"
LOG="$LOG_DIR/build-$(date +%Y%m%d-%H%M%S).log"
BUNDLE_DIR="/tmp"
GH_REPO="nestorchurin/Mine-imator-2.0.2-Continuation-Build-Linux"

# ── colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}▶ $*${RESET}"; }
success() { echo -e "${GREEN}✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✗ $*${RESET}" >&2; }
step()    { echo -e "\n${BOLD}── $* ──────────────────────────────────${RESET}"; }

# ── parse args ───────────────────────────────────────────────────────────────
DO_RELEASE=false
for arg in "$@"; do
    case "$arg" in
        --release) DO_RELEASE=true ;;
        --help|-h)
            echo "Usage: $0 [--release]"
            echo "  (no args)   Build and install Flatpak locally"
            echo "  --release   Also commit, push, export .flatpak and upload to GitHub release"
            exit 0 ;;
        *) error "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── pre-flight checks ────────────────────────────────────────────────────────
step "Pre-flight checks"

if ! flatpak info org.flatpak.Builder &>/dev/null; then
    error "org.flatpak.Builder not installed. Run: flatpak install flathub org.flatpak.Builder"
    exit 1
fi
success "org.flatpak.Builder found"

if [[ "$DO_RELEASE" == "true" ]]; then
    if ! command -v gh &>/dev/null; then
        error "gh (GitHub CLI) not found — needed for --release"
        exit 1
    fi
    if ! gh auth status &>/dev/null; then
        error "Not logged in to GitHub CLI. Run: gh auth login"
        exit 1
    fi
    success "GitHub CLI authenticated"
fi

mkdir -p "$LOG_DIR"

# ── clean up stale FUSE mounts ───────────────────────────────────────────────
step "Cleaning up stale FUSE mounts"
ROFILES_DIR="$REPO_ROOT/.flatpak-builder/rofiles"
if [[ -d "$ROFILES_DIR" ]]; then
    for mp in "$ROFILES_DIR"/rofiles-*; do
        [[ -d "$mp" ]] || continue
        fusermount -uz "$mp" 2>/dev/null && warn "Unmounted $mp" || true
        rm -rf "$mp" 2>/dev/null || true
    done
fi
success "FUSE mounts clean"

# ── build ────────────────────────────────────────────────────────────────────
step "Building Flatpak (log: $LOG)"
info "This takes a few minutes on first run, faster with ccache after that."

cd "$REPO_ROOT"

# Run build and stream output to both terminal and log
flatpak run --command=flathub-build org.flatpak.Builder \
    --disable-cache --install "$MANIFEST" 2>&1 | tee "$LOG" | \
    grep --line-buffered -E \
        'Building CXX|Building C |Linking|Installing|Exporting|Success|error:|FAILED|ninja: build stopped|FB: Running.*cmake|FB: Running.*ninja|Starting build|Committing' \
    | while IFS= read -r line; do
        if echo "$line" | grep -qiE 'error:|FAILED|ninja: build stopped'; then
            echo -e "${RED}$line${RESET}"
        elif echo "$line" | grep -qiE 'Success|Installing app|Exporting'; then
            echo -e "${GREEN}$line${RESET}"
        else
            echo -e "${CYAN}$line${RESET}"
        fi
    done

# Check if build actually succeeded
if ! grep -q 'Installing app/com.nestor_churin.MineImator' "$LOG"; then
    error "Build failed! Full log: $LOG"
    grep -E 'error:|FAILED|ninja: build stopped' "$LOG" | head -20 || true
    exit 1
fi

success "Build and install completed"

# ── done if not release ──────────────────────────────────────────────────────
if [[ "$DO_RELEASE" == "false" ]]; then
    echo ""
    success "Done! Run with:  flatpak run com.nestor_churin.MineImator"
    exit 0
fi

# ── release flow ─────────────────────────────────────────────────────────────
step "Release flow"

# Determine version from latest git tag or ask
LATEST_TAG="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || echo "")"
echo -e "${BOLD}Latest tag: ${LATEST_TAG:-none}${RESET}"
read -rp "Enter new version tag (e.g. 26.2): " VERSION
if [[ -z "$VERSION" ]]; then
    error "Version cannot be empty"
    exit 1
fi

BUNDLE="$BUNDLE_DIR/mine-imator-${VERSION}-linux-x86_64.flatpak"

# Commit any staged/changed tracked files
info "Committing changes..."
cd "$REPO_ROOT"
git add -u
if git diff --cached --quiet; then
    warn "Nothing to commit (working tree clean for tracked files)"
else
    read -rp "Commit message (blank = auto): " COMMIT_MSG
    if [[ -z "$COMMIT_MSG" ]]; then
        COMMIT_MSG="Mine-imator $VERSION Linux build"
    fi
    git commit -m "$COMMIT_MSG"
    success "Committed"
fi

# Tag
if git tag | grep -qx "$VERSION"; then
    warn "Tag $VERSION already exists — skipping tag creation"
else
    git tag -a "$VERSION" -m "Mine-imator $VERSION — Linux Flatpak port"
    success "Tagged $VERSION"
fi

# Push
info "Pushing to fork..."
git push fork master
git push fork "$VERSION"
success "Pushed"

# Export .flatpak bundle
info "Exporting .flatpak bundle..."
flatpak build-bundle \
    "$FLATPAK_REPO" "$BUNDLE" \
    com.nestor_churin.MineImator master \
    --runtime-repo=https://flathub.org/repo/flathub.flatpakrepo
success "Bundle: $BUNDLE ($(du -sh "$BUNDLE" | cut -f1))"

# Create or update GitHub release
if gh release view "$VERSION" --repo "$GH_REPO" &>/dev/null; then
    info "Release $VERSION already exists — uploading asset..."
    gh release upload "$VERSION" "$BUNDLE" --repo "$GH_REPO" --clobber
else
    info "Creating release $VERSION..."
    gh release create "$VERSION" "$BUNDLE" \
        --repo "$GH_REPO" \
        --title "Mine-imator $VERSION — Linux Flatpak port" \
        --notes "$(cat <<NOTES
## Mine-imator $VERSION — Linux Flatpak port

Community-maintained Linux fork of [Mine-imator 2.0.2 Continuation Build](https://github.com/mbandersmc/Mine-imator-2.0.2-Continuation-Build).

> **Vibe-coded with GitHub Copilot**

### Install

\`\`\`bash
flatpak install flathub org.kde.Platform//5.15-25.08
flatpak install mine-imator-${VERSION}-linux-x86_64.flatpak
flatpak run com.nestor_churin.MineImator
\`\`\`

See [CHANGELOG.md](https://github.com/${GH_REPO}/blob/master/CHANGELOG.md) for details.
NOTES
)"
fi

echo ""
success "Release $VERSION published: https://github.com/$GH_REPO/releases/tag/$VERSION"
