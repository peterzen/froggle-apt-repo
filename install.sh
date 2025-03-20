#!/bin/sh


REPO_URL=https://raw.githubusercontent.com/peterzen/froggle-apt-repo/master
APT_KEY=/etc/apt/trusted.gpg.d/froggle-apt.gpg

sudo apt-get install -y wget software-properties-common

# Download the GPG key in binary format (dearmored)
wget -O- "$REPO_URL/pubkey.asc" | gpg --dearmor | sudo tee "$APT_KEY" > /dev/null

# Ensure correct permissions
sudo chmod 644 "$APT_KEY"

echo "deb [signed-by=$APT_KEY] $REPO_URL bookworm main" | sudo tee /etc/apt/sources.list.d/froggle.list