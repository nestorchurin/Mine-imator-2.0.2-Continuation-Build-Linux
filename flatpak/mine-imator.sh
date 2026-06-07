#!/usr/bin/env bash
set -e

# Keep user data in the sandboxed home directory.
mkdir -p "${HOME}/Mine-imator"

# Mine-imator uses cursor warping APIs unsupported by native Wayland.
# Prefer X11 via XWayland when available to restore expected cursor behavior.
if [ -z "${QT_QPA_PLATFORM:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${DISPLAY:-}" ]; then
	export QT_QPA_PLATFORM=xcb
fi

cd /app/bin
exec ./Mine-imator "$@"
