#!/bin/sh
# Download and install the prebuilt binary for this platform.
set -e

REPO="abogdan/ada-dist"
INSTALL_DIR="${INSTALL_DIR:-$HOME/bin}"

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "unsupported architecture: $ARCH" >&2; exit 1 ;;
esac
case "$OS" in
  linux|darwin) ;;
  *) echo "unsupported OS: $OS (on Windows, run inside WSL2)" >&2; exit 1 ;;
esac
ASSET="ada-${OS}-${ARCH}"

# Resolve the newest release via GitHub's web redirect (github.com), not the API
# (api.github.com), which rate-limits unauthenticated callers at 60/hr:
# /releases/latest 302-redirects to /releases/tag/<tag>.
LATEST=$(curl -fsSI "https://github.com/${REPO}/releases/latest" \
  | tr -d '\r' \
  | awk 'tolower($1)=="location:"{print $2}' \
  | sed 's#.*/tag/##' \
  | head -1)
if [ -z "$LATEST" ]; then
  echo "could not determine latest release" >&2
  exit 1
fi

base="https://github.com/${REPO}/releases/download/${LATEST}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "downloading ada ${LATEST} (${OS}/${ARCH})…"
curl -fsSL "${base}/${ASSET}" -o "${tmp}/ada"

# Verify against the published checksums when available.
if curl -fsSL "${base}/SHA256SUMS" -o "${tmp}/SHA256SUMS" 2>/dev/null; then
  want=$(grep " ${ASSET}\$" "${tmp}/SHA256SUMS" | awk '{print $1}')
  if [ -n "$want" ]; then
    if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "${tmp}/ada" | awk '{print $1}')
    else got=$(shasum -a 256 "${tmp}/ada" | awk '{print $1}'); fi
    if [ "$want" != "$got" ]; then
      echo "checksum mismatch for ${ASSET}: expected $want, got $got" >&2
      exit 1
    fi
  fi
fi

mkdir -p "$INSTALL_DIR"
chmod +x "${tmp}/ada"
mv "${tmp}/ada" "${INSTALL_DIR}/ada"
echo "installed ada to ${INSTALL_DIR}/ada"
echo ""
if echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo "run: ada init"
else
  echo "add ${INSTALL_DIR} to your PATH, then run: ada init"
fi
