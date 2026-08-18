#!/usr/bin/env bash
set -euo pipefail

# paste ssh key
read -rp "paste ssh public key and press enter to continue... " PUBKEY
ssh-keygen -lf /dev/stdin <<<"$PUBKEY" >/dev/null || { echo "public key not valid... "; exit 1; }

# add user
id admin &>/dev/null || adduser admin
usermod -aG sudo admin

# installing

## caddy setup
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list

## knot setup
wget -O /usr/share/keyrings/cznic-labs-pkg.gpg https://pkg.labs.nic.cz/gpg
echo "deb [signed-by=/usr/share/keyrings/cznic-labs-pkg.gpg] https://pkg.labs.nic.cz/knot-dns trixie main" | tee /etc/apt/sources.list.d/cznic-labs-knot-dns.list

## software
apt update
apt upgrade -y
apt install -y git caddy fail2ban ufw unattended-upgrades knot knot-dnssecutils knot-dnsutils knot-keymgr debian-keyring debian-archive-keyring apt-transport-https ca-certificates php php-fpm fastfetch
[ -d /srv/www/toprakkilic.com/.git ] || git clone https://github.com/topklc/toprakkilic.com /srv/www/toprakkilic.com

# security config

## firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443
ufw allow 53
ufw --force enable

## ssh
install -d -m 700 -o admin -g admin /home/admin/.ssh
echo "$PUBKEY" > /home/admin/.ssh/authorized_keys
chown admin:admin /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys
install -o root -g admin -m 640 /srv/www/toprakkilic.com/config/00-hardening.conf /etc/ssh/sshd_config.d/00-hardening.conf
/usr/sbin/sshd -t
systemctl restart ssh
systemctl enable --now fail2ban
fail2ban-client status sshd

# website init
chown -R admin:admin /srv/www/toprakkilic.com
install -m 640 -g admin /srv/www/toprakkilic.com/config/Caddyfile /etc/caddy/Caddyfile
systemctl enable --now caddy php8.4-fpm
systemctl reload caddy

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
systemctl restart knot

## regisrar updates
echo "glue ns1/ns2.toprakkilic.com records in registrar and press enter to continue...  "
echo "ipv4... $(curl -fsS -4 https://ifconfig.co 2>/dev/null || echo 'none')"
echo "ipv6... $(curl -fsS -6 https://ifconfig.co 2>/dev/null || echo 'none')"
read -r
echo "update dnssec records and press enter to continue..."
keymgr toprakkilic.com. ds
read -r

# verification
read -rp "verify NOW ssh admin@<ip> works before closing this terminal... [y/N] " ok
if [[ "$ok" == [yY] ]]; then
passwd -l root
echo "root locked... " 
sleep 5
kill -HUP $PPID
else
echo "root NOT locked, when verified, run sudo passwd -l root... "
fi