#!/bin/sh
# Install ./out/*.deb on this (throwaway) system, check they took effect,
# then purge and check nothing is left behind. Run as root, e.g. in CI.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

apt-get install -y ./out/*.deb

for crt in packages/froggle-ca/certs/*.crt; do
    openssl verify -CApath /etc/ssl/certs "$crt" >/dev/null || fail "$crt not trusted"
done
dpkg-divert --list | grep -q 'froggle-ws' || fail "no GTK diversion"
[ -L /etc/gtk-3.0/settings.ini ] || fail "/etc/gtk-3.0/settings.ini not replaced"

pkgs=$(for d in out/*.deb; do dpkg-deb -f "$d" Package; done)
apt-get purge -y $pkgs

! ls /etc/ssl/certs | grep -qi froggle || fail "cert links left in /etc/ssl/certs"
! dpkg-divert --list | grep -q froggle || fail "diversions left"
[ ! -e /etc/dconf/db/local ] || fail "dconf db left"

echo "install/purge OK"
