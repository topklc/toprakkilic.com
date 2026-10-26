#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root... "; exit 1; }

read -rp "set username and press enter to continue.. " USER
apt install -y radicale apache2-utils
htpasswd -5 -c /etc/radicale/users "$USER"
cp /srv/www/toprakkilic.com/config /etc/radicale/
systemctl enable radicale
systemctl start radicale