#!/usr/bin/env bash
# run as root
set -euo pipefail

# add user and prepare
sudo apt update && sudo apt upgrade -y
id topklc &>/dev/null || sudo adduser topklc
sudo usermod -aG sudo topklc

# install apps
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list > /dev/null
sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg
sudo chmod o+r /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install -y caddy fail2ban ufw git unattended-upgrades rsync

# ufw setup
sudo ufw default deny incoming && sudo ufw default allow outgoing
sudo ufw allow 22/tcp && sudo ufw allow 80/tcp && sudo ufw allow 443
sudo ufw --force enable

# ssh setup
sudo install -d -m 700 -o topklc -g topklc /home/topklc/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGj+SPcse4+t5DwxANveRrHxsZriCZLdu6NKb+4oELZmN lenovo@t440p" \
| sudo tee /home/topklc/.ssh/authorized_keys > /dev/null
sudo chown topklc:topklc /home/topklc/.ssh/authorized_keys
sudo chmod 600 /home/topklc/.ssh/authorized_keys

sudo tee /etc/ssh/sshd_config.d/hardening.conf > /dev/null <<'EOF'
PasswordAuthentication no
PermitRootLogin no
KbdInteractiveAuthentication no
AllowUsers topklc
EOF
sudo sshd -t || { echo "sshd config invalid — aborting before lockout"; exit 1; }
sudo systemctl restart ssh

# website init
sudo mkdir -p /srv/www
[ -d /srv/www/toprakkilic.com/.git ] || sudo git clone https://github.com/topklc/toprakkilic.com /srv/www/toprakkilic.com
sudo chown -R topklc:topklc /srv/www/toprakkilic.com

sudo tee /etc/caddy/Caddyfile > /dev/null <<'EOF'
toprakkilic.com, mta-sts.toprakkilic.com, openpgpkey.toprakkilic.com {
    root * /srv/www/toprakkilic.com
    encode
    file_server
    @notpublic path /.git/* /Caddyfile /README.md /LICENSE /_headers /.gitignore
    respond @notpublic 404
    header /.well-known/openpgpkey/* Access-Control-Allow-Origin "*"
}
www.toprakkilic.com {
    redir https://toprakkilic.com{uri} permanent
}
EOF
sudo caddy validate --config /etc/caddy/Caddyfile || { echo "Caddyfile invalid — aborting"; exit 1; }
sudo systemctl enable --now caddy fail2ban

# final touches
id -nG topklc | grep -qw sudo || { echo "topklc lacks sudo — NOT locking root"; exit 1; }

# verification
read -rp "verify NOW ssh topklc@<ip> works before closing this terminal [y/N] " ok
if [[ "$ok" == [yY] ]]; then
    sudo passwd -l root
    echo "root locked"
else
    echo "root NOT locked, when verified, run sudo passwd -l root"
fi