#!/usr/bin/env bash
set -euo pipefail

# paste ssh key
read -rp "paste ssh public key: " PUBKEY
ssh-keygen -lf /dev/stdin <<<"$PUBKEY" >/dev/null || { echo "public key not valid restart script"; exit 1; }

# add user and prepare
id admin &>/dev/null || adduser admin
usermod -aG sudo admin
apt update
apt upgrade -y

# install
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list
wget -O /usr/share/keyrings/cznic-labs-pkg.gpg https://pkg.labs.nic.cz/gpg
echo "deb [signed-by=/usr/share/keyrings/cznic-labs-pkg.gpg] https://pkg.labs.nic.cz/knot-dns trixie main" | sudo tee /etc/apt/sources.list.d/cznic-labs-knot-dns.list 
apt update
apt install -y apt-transport-https ca-certificates git caddy fail2ban ufw unattended-upgrades knot knot-dnssecutils knot-dnsutils knot-keymgr

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

# tsig key for zone transfers
if [ ! -s /etc/knot/keys.conf ]; then
install -m 640 -g knot /dev/null /etc/knot/keys.conf
printf 'key:\n  - id: xfer-key\n    algorithm: hmac-sha256\n    secret: "%s"\n' \
"$(head -c 32 /dev/urandom | base64)" > /etc/knot/keys.conf
fi

# dns setup
cp /srv/www/toprakkilic.com/config/knot.conf /etc/knot/knot.conf
install -D -m 640 -o knot -g knot \
/srv/www/toprakkilic.com/config/toprakkilic.com.zone /var/lib/knot/zones/toprakkilic.com.zone
systemctl enable knot
systemctl restart knot

# dns updating
echo "glue ns1/ns2.toprakkilic.com records in registrar... "
echo "ipv4... $(curl -fsS -4 https://ifconfig.co 2>/dev/null || echo 'none')"
echo "ipv6... $(curl -fsS -6 https://ifconfig.co 2>/dev/null || echo 'none')"
read -rp "press enter to continue... "
echo "make sure to update regisrar DNSSEC records..."
keymgr toprakkilic.com. ds
read -rp "press enter to continue... "

# verification
read -rp "verify NOW ssh admin@<ip> works before closing this terminal... [y/N] " ok
if [[ "$ok" == [yY] ]]; then
passwd -l root
echo "root locked"
else
echo "root NOT locked, when verified, run sudo passwd -l root"
fi