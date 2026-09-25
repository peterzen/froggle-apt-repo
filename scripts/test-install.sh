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
for f in /etc/gtk-3.0/settings.ini /etc/gtk-4.0/settings.ini \
         /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml; do
    [ -L "$f" ] || fail "$f not replaced"
done
grep -q 'value="Adwaita-dark"' /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    || fail "xsettings.xml not dark"
grep -q '^color-scheme=.prefer-dark.' /usr/share/glib-2.0/schemas/*froggle-ws.gschema.override \
    || fail "no gsettings override"
(. /etc/profile.d/froggle-qt.sh; [ "$QT_QPA_PLATFORMTHEME" = qt5ct ]) || fail "Qt env not set"

pkgs=$(for d in out/*.deb; do dpkg-deb -f "$d" Package; done)
apt-get purge -y $pkgs

! ls /etc/ssl/certs | grep -qi froggle || fail "cert links left in /etc/ssl/certs"
! dpkg-divert --list | grep -q froggle || fail "diversions left"
! ls /usr/share/glib-2.0/schemas/ | grep -q froggle || fail "gsettings override left"

echo "install/purge OK"
