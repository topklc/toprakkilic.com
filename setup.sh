#!/usr/bin/env bash
# run as root: sudo bash setup.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "run with sudo" >&2
    exit 1
fi

REPO=/srv/www/toprakkilic.com

# add user and prepare
apt update && apt upgrade -y
id admin &>/dev/null || adduser admin
usermod -aG sudo admin

# install apps
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
chmod o+r /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install -y caddy fail2ban ufw git unattended-upgrades knot knot-dnsutils

# ufw setup
ufw default deny incoming && ufw default allow outgoing
ufw allow 22/tcp && ufw allow 80/tcp && ufw allow 443 && ufw allow 53
ufw --force enable

# ssh setup
install -d -m 700 -o admin -g admin /home/admin/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGj+SPcse4+t5DwxANveRrHxsZriCZLdu6NKb+4oELZmN lenovo@t440p" \
    > /home/admin/.ssh/authorized_keys
chown admin:admin /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys

tee /etc/ssh/sshd_config.d/hardening.conf > /dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
AllowUsers admin
EOF
/usr/sbin/sshd -t || { echo "sshd config invalid — aborting before lockout"; exit 1; }
systemctl restart ssh

# website init
mkdir -p /srv/www
[ -d "$REPO/.git" ] || git clone https://github.com/topklc/toprakkilic.com "$REPO"
chown -R admin:admin "$REPO"
cp "$REPO/config/Caddyfile" /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile || { echo "Caddyfile invalid — aborting"; exit 1; }
systemctl enable --now caddy fail2ban
systemctl reload caddy

# dns init
bash "$REPO/config/deploy.sh"

# final touches
id -nG admin | grep -qw sudo || { echo "admin lacks sudo — NOT locking root"; exit 1; }

# verification
read -rp "verify NOW ssh admin@<ip> works before closing this terminal [y/N] " ok
if [[ "$ok" == [yY] ]]; then
    passwd -l root
    echo "root locked"
else
    echo "root NOT locked, when verified, run sudo passwd -l root"
fi
