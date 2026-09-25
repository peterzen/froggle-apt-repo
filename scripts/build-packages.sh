#!/bin/sh
# Build every package under packages/ into ./out/.
# Usage: scripts/build-packages.sh [package...]
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT="$ROOT/out"
mkdir -p "$OUT"

if [ $# -eq 0 ]; then
    set -- $(ls "$ROOT/packages")
fi

for pkg in "$@"; do
    src="$ROOT/packages/$pkg"
    echo "==> building $pkg"
    # dpkg-buildpackage writes results to the parent dir, so build from a
    # scratch copy to keep packages/ clean.
    work=$(mktemp -d)
    cp -a "$src" "$work/$pkg"
    (cd "$work/$pkg" && dpkg-buildpackage --build=binary --no-sign -us -uc)
    mv "$work"/*.deb "$OUT/"
    rm -rf "$work"
done

ls -l "$OUT"
