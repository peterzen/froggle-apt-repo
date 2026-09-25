#!/bin/sh
# Assemble a signed apt repository from ./out/*.deb into ./public/.
# Signing key: the secret key must already be in the gpg keyring;
# set SIGNING_KEY_ID to pick it (defaults to gpg's default key).
set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PUB="$ROOT/public"
SUITE=stable
CODENAME=froggle
COMPONENT=main
ARCHES="amd64 arm64"

rm -rf "$PUB"
mkdir -p "$PUB/pool/$COMPONENT"
cp "$ROOT"/out/*.deb "$PUB/pool/$COMPONENT/"

cd "$PUB"
for arch in $ARCHES; do
    dir="dists/$CODENAME/$COMPONENT/binary-$arch"
    mkdir -p "$dir"
    apt-ftparchive --arch "$arch" packages "pool/$COMPONENT" > "$dir/Packages"
    gzip -9kn "$dir/Packages"
done

apt-ftparchive \
    -o APT::FTPArchive::Release::Origin=Froggle \
    -o APT::FTPArchive::Release::Label=Froggle \
    -o APT::FTPArchive::Release::Suite="$SUITE" \
    -o APT::FTPArchive::Release::Codename="$CODENAME" \
    -o APT::FTPArchive::Release::Components="$COMPONENT" \
    -o APT::FTPArchive::Release::Architectures="$ARCHES all" \
    -o APT::FTPArchive::Release::Description="FROGGLE apt repository" \
    release "dists/$CODENAME" > Release.tmp
# Written outside dists/ so the Release file doesn't list itself.
mv Release.tmp "dists/$CODENAME/Release"

GPG="gpg --batch --yes ${SIGNING_KEY_ID:+--local-user $SIGNING_KEY_ID}"
$GPG --clearsign -o "dists/$CODENAME/InRelease" "dists/$CODENAME/Release"
$GPG --armor --detach-sign -o "dists/$CODENAME/Release.gpg" "dists/$CODENAME/Release"

# Public key + client setup script, served next to the repo.
$GPG --armor --export ${SIGNING_KEY_ID:-} > froggle.asc
cp "$ROOT/install.sh" install.sh
touch .nojekyll

find . -type f | sort
