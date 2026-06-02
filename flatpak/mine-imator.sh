#!/usr/bin/env bash
set -e

# Keep user data in the sandboxed home directory.
mkdir -p "${HOME}/Mine-imator"

exec /app/bin/Mine-imator "$@"
