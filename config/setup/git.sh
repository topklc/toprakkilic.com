#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root... "; exit 1; }

id git &>/dev/null || adduser --shell /usr/bin/git-shell git
mkdir -p /home/git/.ssh
chmod 700 /home/git/.ssh
read -rp "Enter SSH public key and press enter... " key
echo "$key" > /home/git/.ssh/authorized_keys
chmod 600 /home/git/.ssh/authorized_keys
chown -R git:git /home/git/.ssh
mkdir -p /srv/git
chown git:git /srv/git
passwd -l git