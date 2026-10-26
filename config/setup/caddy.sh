#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root... "; exit 1; }

## caddy setup
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list

# caddy init
apt update
apt upgrade -y
apt install -y php-fpm php-cli caddy
chown -R admin:admin /srv/www/toprakkilic.com
chown -R root:root /etc/caddy
chmod 755 /etc/caddy
install -m 640 -o root -g caddy /srv/www/toprakkilic.com/config/Caddyfile /etc/caddy/Caddyfile
usermod -aG www-data caddy
systemctl enable --now php8.4-fpm caddy
systemctl restart caddy

## firewall
ufw allow 80/tcp
ufw allow 443
systemctl restart ufw