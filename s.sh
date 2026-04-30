#!/usr/bin/env bash
set -euo pipefail

ARCH="$(dpkg --print-architecture)"

echo "==> Updating apt and applying pending upgrades"
sudo apt update
sudo apt full-upgrade -y

echo "==> Adding Brave apt repository"
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

sudo tee /etc/apt/sources.list.d/brave-browser-release.sources > /dev/null <<EOF
Types: deb
URIs: https://brave-browser-apt-release.s3.brave.com
Suites: stable
Components: main
Architectures: ${ARCH}
Signed-By: /usr/share/keyrings/brave-browser-archive-keyring.gpg
EOF

echo "==> Installing Brave and Ansible"
sudo apt update
sudo apt install -y brave-browser ansible
