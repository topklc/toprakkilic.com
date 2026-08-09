#!/usr/bin/env bash
set -euo pipefail

# paste ssh key
read -rp "paste ssh public key " PUBKEY

# add user and prepare
apt update
apt upgrade -y
id admin &>/dev/null || adduser admin
usermod -aG sudo admin

# install
apt install -y sudo caddy fail2ban ufw git unattended-upgrades knot

# firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443
ufw allow 53
ufw --force enable

# ssh
install -d -m 700 -o admin -g admin /home/admin/.ssh
echo "$PUBKEY" > /home/admin/.ssh/authorized_keys
chown admin:admin /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys

cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
AllowUsers admin
EOF
/usr/sbin/sshd -t
systemctl restart ssh

# website
[ -d /srv/www/toprakkilic.com/.git ] || git clone https://github.com/topklc/toprakkilic.com /srv/www/toprakkilic.com
chown -R admin:admin /srv/www/toprakkilic.com
cp /srv/www/toprakkilic.com/config/Caddyfile /etc/caddy/Caddyfile
systemctl enable --now caddy fail2ban
systemctl reload caddy

# dns
if [ ! -s /etc/knot/keys.conf ]; then
install -m 640 -g knot /dev/null /etc/knot/keys.conf
printf 'key:\n  - id: xfer-key\n    algorithm: hmac-sha256\n    secret: "%s"\n' \
"$(head -c 32 /dev/urandom | base64)" > /etc/knot/keys.conf
fi

# dns
cp /srv/www/toprakkilic.com/config/knot.conf /etc/knot/knot.conf
install -D -m 640 -o knot -g knot \
/srv/www/toprakkilic.com/config/toprakkilic.com.zone /var/lib/knot/zones/toprakkilic.com.zone
systemctl enable knot
systemctl restart knot

# verification
read -rp "verify NOW ssh admin@<ip> works before closing this terminal [y/N] " ok
if [[ "$ok" == [yY] ]]; then
passwd -l root
echo "root locked"
else
echo "root NOT locked, when verified, run sudo passwd -l root"
fi