#!/bin/sh
# Install ./out/*.deb on this (throwaway) system, check they took effect,
# then purge and check nothing is left behind. Run as root, e.g. in CI.
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

fail() { echo "FAIL: $*" >&2; exit 1; }

apt-get install -y ./out/*.deb

BUNDLE=/etc/ssl/certs/ca-certificates.crt
trusted() {
    openssl verify -CApath /etc/ssl/certs "$1" >/dev/null 2>&1 &&
        grep -qF "$(sed -n 2p "$1")" "$BUNDLE"
}
check_ca() {
    for crt in packages/froggle-ca/certs/*.crt; do
        grep -qx "froggle/${crt##*/}" /etc/ca-certificates.conf \
            || fail "${crt##*/} not enabled in ca-certificates.conf ($1)"
        trusted "$crt" || fail "${crt##*/} not trusted ($1)"
    done
}
check_ca "install"

# Survives ca-certificates rewriting its config.
apt-get install -y --reinstall ca-certificates
check_ca "ca-certificates reinstall"
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure ca-certificates
check_ca "dpkg-reconfigure ca-certificates"

# Entries left "!"-disabled by ca-certificates are re-enabled by our postinst.
sed -i 's|^froggle/|!froggle/|' /etc/ca-certificates.conf
update-ca-certificates --fresh
! trusted packages/froggle-ca/certs/FROGGLE-CA.crt || fail "disabling had no effect"
dpkg-reconfigure froggle-ca
check_ca "re-enabled by postinst"

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

# froggle-qubes-keepassxc-wrapper: manifests point at the wrapper, and the
# wrapper runs qrexec-client-vm (faked here) against the configured vault.
HOST=org.keepassxc.keepassxc_browser.json
for m in /usr/lib/mozilla/native-messaging-hosts/$HOST \
         /etc/chromium/native-messaging-hosts/$HOST \
         /etc/opt/chrome/native-messaging-hosts/$HOST; do
    grep -q '"path": "/usr/bin/keepassxc-proxy-qrexec"' "$m" || fail "$m missing or wrong"
done
fake=$(mktemp -d)
printf '#!/bin/sh\necho "$@"\n' > "$fake/qrexec-client-vm"
chmod +x "$fake/qrexec-client-vm"
[ "$(PATH="$fake:$PATH" keepassxc-proxy-qrexec /manifest ext-id)" = "vault custom.KeePassXC" ] \
    || fail "wrapper does not call qrexec-client-vm vault custom.KeePassXC"
sed -i 's/^KEEPASSXC_VAULT=.*/KEEPASSXC_VAULT=pw-vault/' /etc/default/keepassxc-proxy-qrexec
[ "$(PATH="$fake:$PATH" keepassxc-proxy-qrexec)" = "pw-vault custom.KeePassXC" ] \
    || fail "wrapper ignores /etc/default/keepassxc-proxy-qrexec"

# froggle-qubes-split-ssh: socket enabled for all users, ssh and the session
# pointed at it, and the helper calls qrexec-client-vm (faked above) with
# @default unless the AppVM names a vault in /rw/config/split-ssh-vault.
SOCKET_WANT=/etc/systemd/user/sockets.target.wants/qubes-split-ssh.socket
[ -L "$SOCKET_WANT" ] || fail "qubes-split-ssh.socket not enabled globally"
grep -qx 'IdentityAgent /run/user/%i/qubes-split-ssh.sock' \
    /etc/ssh/ssh_config.d/50-qubes-split-ssh.conf || fail "ssh IdentityAgent not set"
grep -qx 'SSH_AUTH_SOCK=${XDG_RUNTIME_DIR}/qubes-split-ssh.sock' \
    /etc/environment.d/50-qubes-split-ssh.conf || fail "SSH_AUTH_SOCK not set"
[ "$(PATH="$fake:$PATH" qubes-split-ssh-connect)" = "@default qubes.SshAgent" ] \
    || fail "split-ssh helper does not call qrexec-client-vm @default qubes.SshAgent"
mkdir -p /rw/config
echo ssh-vault > /rw/config/split-ssh-vault
[ "$(PATH="$fake:$PATH" qubes-split-ssh-connect)" = "ssh-vault qubes.SshAgent" ] \
    || fail "split-ssh helper ignores /rw/config/split-ssh-vault"
rm -rf /rw

pkgs=$(for d in out/*.deb; do dpkg-deb -f "$d" Package; done)
apt-get purge -y $pkgs

! ls /etc/ssl/certs | grep -qi froggle || fail "cert links left in /etc/ssl/certs"
for f in /usr/bin/keepassxc-proxy-qrexec /etc/default/keepassxc-proxy-qrexec \
         /usr/lib/mozilla/native-messaging-hosts/$HOST \
         /etc/chromium/native-messaging-hosts/$HOST /etc/opt/chrome/native-messaging-hosts/$HOST \
         /usr/bin/qubes-split-ssh-connect /usr/lib/systemd/user/qubes-split-ssh.socket \
         /usr/lib/systemd/user/qubes-split-ssh@.service "$SOCKET_WANT" \
         /etc/ssh/ssh_config.d/50-qubes-split-ssh.conf /etc/environment.d/50-qubes-split-ssh.conf; do
    [ ! -e "$f" ] && [ ! -L "$f" ] || fail "$f left after purge"
done
! grep -q 'froggle/' /etc/ca-certificates.conf || fail "entries left in ca-certificates.conf"
for crt in packages/froggle-ca/certs/*.crt; do
    ! trusted "$crt" || fail "${crt##*/} still trusted after purge"
done
! dpkg-divert --list | grep -q froggle || fail "diversions left"
! ls /usr/share/glib-2.0/schemas/ | grep -q froggle || fail "gsettings override left"

echo "install/purge OK"
