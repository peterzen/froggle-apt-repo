#!/bin/sh


REPO_URL=https://raw.githubusercontent.com/peterzen/froggle-apt-repo/master

sudo apt-get install -y curl software-properties-common

curl -s $REPO_URL/pubkey.asc | sudo apt-key add -

sudo add-apt-repository -y "deb [arch=amd64] $REPO_URL bookworm main"
