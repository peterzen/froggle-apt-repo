#!/bin/sh
# Assemble a signed apt repository from ./out/*.deb into ./public/.
# Signing key: the secret key must already be in the gpg keyring;
# set SIGNING_KEY_ID to pick it (defaults to gpg's default key).
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PUB="$ROOT/public"
# One suite per supported Debian release. All packages are Architecture: all,
# so every suite indexes the same pool.
CODENAMES="bookworm trixie"
COMPONENT=main
ARCHES="amd64 arm64"

rm -rf "$PUB"
mkdir -p "$PUB/pool/$COMPONENT"
cp "$ROOT"/out/*.deb "$PUB/pool/$COMPONENT/"

cd "$PUB"
GPG="gpg --batch --yes ${SIGNING_KEY_ID:+--local-user $SIGNING_KEY_ID}"

for codename in $CODENAMES; do
    for arch in $ARCHES; do
        dir="dists/$codename/$COMPONENT/binary-$arch"
        mkdir -p "$dir"
        apt-ftparchive --arch "$arch" packages "pool/$COMPONENT" > "$dir/Packages"
        gzip -9kn "$dir/Packages"
    done

    apt-ftparchive \
        -o APT::FTPArchive::Release::Origin=Froggle \
        -o APT::FTPArchive::Release::Label=Froggle \
        -o APT::FTPArchive::Release::Suite="$codename" \
        -o APT::FTPArchive::Release::Codename="$codename" \
        -o APT::FTPArchive::Release::Components="$COMPONENT" \
        -o APT::FTPArchive::Release::Architectures="$ARCHES all" \
        -o APT::FTPArchive::Release::Description="FROGGLE apt repository ($codename)" \
        release "dists/$codename" > Release.tmp
    # Written outside dists/ so the Release file doesn't list itself.
    mv Release.tmp "dists/$codename/Release"

    $GPG --clearsign -o "dists/$codename/InRelease" "dists/$codename/Release"
    $GPG --armor --detach-sign -o "dists/$codename/Release.gpg" "dists/$codename/Release"
done

# Public key + client setup script, served next to the repo.
$GPG --armor --export ${SIGNING_KEY_ID:-} > froggle.asc
cp "$ROOT/install.sh" install.sh

find . -type f | sort
