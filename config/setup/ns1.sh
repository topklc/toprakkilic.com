#!/usr/bin/env bash
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run as root... "; exit 1; }

# installing

## knot setup
wget -O /usr/share/keyrings/cznic-labs-pkg.gpg https://pkg.labs.nic.cz/gpg
echo "deb [signed-by=/usr/share/keyrings/cznic-labs-pkg.gpg] https://pkg.labs.nic.cz/knot-dns trixie main" | tee /etc/apt/sources.list.d/cznic-labs-knot-dns.list

## software
apt update
apt upgrade -y
apt install -y knot knot-dnssecutils knot-dnsutils knot-keymgr debian-keyring debian-archive-keyring apt-transport-https ca-certificates

# security config

## firewall
ufw allow 53
systemctl restart ufw

# website init
chown -R admin:admin /srv/www/toprakkilic.com
chown -R root:root /etc/caddy
chmod 755 /etc/caddy
install -m 640 -o root -g caddy /srv/www/toprakkilic.com/config/Caddyfile /etc/caddy/Caddyfile
usermod -aG www-data caddy
systemctl enable --now php8.4-fpm caddy
systemctl restart caddy
# dns

## tsig keygen for zone transfers
if [ ! -s /etc/knot/keys.conf ]; then
install -m 640 -g knot /dev/null /etc/knot/keys.conf
printf 'key:\n  - id: xfer-key\n    algorithm: hmac-sha256\n    secret: "%s"\n' \
"$(head -c 32 /dev/urandom | base64)" > /etc/knot/keys.conf
fi

## dns config init
cp /srv/www/toprakkilic.com/config/knot.conf /etc/knot/knot.conf
install -D -m 640 -o knot -g knot \
/srv/www/toprakkilic.com/config/toprakkilic.com.zone /var/lib/knot/zones/toprakkilic.com.zone
systemctl enable knot
knotc -c /etc/knot/knot.conf conf-check
systemctl restart knot

## regisrar updates
echo "glue ns1/ns2.toprakkilic.com records in registrar and press enter to continue...  "
echo "ipv4... $(curl -fsS -4 https://ifconfig.co 2>/dev/null || echo 'none')"
echo "ipv6... $(curl -fsS -6 https://ifconfig.co 2>/dev/null || echo 'none')"
read -r
echo "update dnssec records and press enter to continue..."
keymgr toprakkilic.com. ds
read -r