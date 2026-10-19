#!/usr/bin/env bash
set -euo pipefail

read -rp "set username and press enter to continue.. " USER
sudo apt install -y radicale apache2-utils
sudo htpasswd -5 -c /etc/radicale/users "$USER"
sudo cp /srv/www/toprakkilic.com/config /etc/radicale/
sudo systemctl enable radicale
sudo systemctl start radicale