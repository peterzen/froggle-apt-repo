#!/bin/sh
# Add the FROGGLE apt repository to this machine.
# Usage: curl -fsSL https://peterzen.github.io/froggle-apt-repo/install.sh | sudo sh
# SUITE defaults to this machine's Debian codename (bookworm or trixie).
set -eu

REPO_URL=${REPO_URL:-https://peterzen.github.io/froggle-apt-repo}
KEYRING=/etc/apt/keyrings/froggle.asc

if [ -z "${SUITE:-}" ]; then
    . /etc/os-release
    SUITE=${VERSION_CODENAME:-}
fi
case "$SUITE" in
    bookworm|trixie) ;;
    *)
        echo "Unsupported release '${SUITE}'; set SUITE=bookworm or SUITE=trixie." >&2
        exit 1
        ;;
esac

install -d -m 0755 /etc/apt/keyrings
curl -fsSL "$REPO_URL/froggle.asc" -o "$KEYRING"
chmod 0644 "$KEYRING"

cat > /etc/apt/sources.list.d/froggle.sources <<SRC
Types: deb
URIs: $REPO_URL
Suites: $SUITE
Components: main
Signed-By: $KEYRING
SRC

apt-get update
