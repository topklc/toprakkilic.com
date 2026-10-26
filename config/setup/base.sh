#!/usr/bin/env bash
set -euo pipefail

# paste ssh key
read -rp "paste ssh public key and press enter to continue... " key
ssh-keygen -lf /dev/stdin <<<"$key" >/dev/null || { echo "public key not valid... "; exit 1; }

# add user
id admin &>/dev/null || adduser admin
usermod -aG sudo admin

# software
apt update
apt upgrade -y
apt install -y git fail2ban ufw unattended-upgrades fastfetch gpg curl
[ -d /srv/www/toprakkilic.com/.git ] || git clone https://github.com/topklc/toprakkilic.com /srv/www/toprakkilic.com

# firewall
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw --force enable
systemctl enable --now ufw

# ssh
install -d -m 700 -o admin -g admin /home/admin/.ssh
install -m 644 -o root -g root /srv/www/toprakkilic.com/config/00-hardening.conf /etc/ssh/sshd_config.d/00-hardening.conf
echo "$key" > /home/admin/.ssh/authorized_keys
chown admin:admin /home/admin/.ssh/authorized_keys
chmod 600 /home/admin/.ssh/authorized_keys
/usr/sbin/sshd -t
systemctl restart ssh
systemctl enable --now fail2ban

# verification
read -rp "verify NOW ssh admin@<ip> works before closing this terminal, press enter to lock root... "
passwd -l root