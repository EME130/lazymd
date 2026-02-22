#!/usr/bin/env bash
set -euo pipefail

# lazy-md installer for Linux
# Usage: curl -fsSL https://raw.githubusercontent.com/EME130/lazymd/main/scripts/install-linux.sh | bash

REPO="EME130/lazymd"
BINARY="lazy-md"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

info()  { printf '\033[1;34m%s\033[0m\n' "$*"; }
error() { printf '\033[1;31mError: %s\033[0m\n' "$*" >&2; exit 1; }

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ZIG_ARCH="x86_64" ;;
    aarch64) ZIG_ARCH="aarch64" ;;
    *)       error "Unsupported architecture: $ARCH. Supported: x86_64, aarch64" ;;
esac

ASSET="${BINARY}-linux-${ZIG_ARCH}.tar.gz"

info "Installing ${BINARY} for Linux ${ZIG_ARCH}..."

# Get latest release tag
LATEST="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)"
if [ -z "$LATEST" ]; then
    error "Could not determine latest release. Check https://github.com/${REPO}/releases"
fi
info "Latest release: ${LATEST}"

# Download
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${LATEST}/${ASSET}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

info "Downloading ${DOWNLOAD_URL}..."
if ! curl -fSL --progress-bar -o "${TMPDIR}/${ASSET}" "$DOWNLOAD_URL"; then
    error "Download failed. Asset '${ASSET}' may not exist for this release.\nTry building from source instead: https://github.com/${REPO}#install"
fi

# Extract
info "Extracting..."
tar -xzf "${TMPDIR}/${ASSET}" -C "$TMPDIR"

# Install
if [ -w "$INSTALL_DIR" ]; then
    cp "${TMPDIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
else
    info "Installing to ${INSTALL_DIR} (requires sudo)..."
    sudo cp "${TMPDIR}/${BINARY}" "${INSTALL_DIR}/${BINARY}"
fi
chmod +x "${INSTALL_DIR}/${BINARY}"

info "Installed ${BINARY} to ${INSTALL_DIR}/${BINARY}"
"${INSTALL_DIR}/${BINARY}" --version 2>/dev/null || true
info "Done! Run '${BINARY}' to get started."
