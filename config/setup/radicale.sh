#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root... "; exit 1; }

read -rp "set username and press enter to continue.. " USER
apt install -y radicale apache2-utils
htpasswd -5 -c /etc/radicale/users "$USER"
cp /srv/www/toprakkilic.com/radicale_config /etc/radicale/config
systemctl enable radicale
systemctl start radicaleapt upgrade -y
apt install -y fail2ban ufw unattended-upgrades knot knot-dnssecutils knot-dnsutils knot-keymgr debian-keyring debian-archive-keyring fastfetch
