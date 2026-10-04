#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root... "; exit 1; }

REPO_RAW="https://raw.githubusercontent.com/topklc/toprakkilic.com/main/config"
NS1_IP="142.248.111.119"
ZONE="toprakkilic.com"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# paste ssh key
read -rp "paste ssh public key and press enter to continue... " PUBKEY
ssh-keygen -lf /dev/stdin <<<"$PUBKEY" >/dev/null || { echo "public key not valid... "; exit 1; }

# add user
id admin &>/dev/null || adduser admin
usermod -aG sudo admin

# installing

## install precs
apt update
apt install -y gpg curl

## knot repo
curl -fsSL https://pkg.labs.nic.cz/gpg -o /usr/share/keyrings/cznic-labs-pkg.gpg
echo "deb [signed-by=/usr/share/keyrings/cznic-labs-pkg.gpg] https://pkg.labs.nic.cz/knot-dns trixie main" \
  > /etc/apt/sources.list.d/cznic-labs-knot-dns.list

## software
apt update
apt upgrade -y
apt install -y fail2ban ufw unattended-upgrades knot knot-dnssecutils knot-dnsutils knot-keymgr \
  debian-keyring debian-archive-keyring fastfetch

# security config

## firewall (ns2 serves dns only — no web ports)
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 53
ufw --force enable

## ssh
install -d -m 700 -o admin -g admin /home/admin/.ssh
printf '%s\n' "$PUBKEY" | install -m 600 -o admin -g admin /dev/stdin /home/admin/.ssh/authorized_keys
curl -fsSL "$REPO_RAW/00-hardening.conf" -o "$TMP/00-hardening.conf"
install -m 644 -o root -g root "$TMP/00-hardening.conf" /etc/ssh/sshd_config.d/00-hardening.conf
/usr/sbin/sshd -t
systemctl restart ssh
systemctl enable --now fail2ban
for i in {1..10}; do fail2ban-client ping &>/dev/null && break; sleep 1; done
fail2ban-client status sshd

# dns

## tsig key
if [ ! -s /etc/knot/keys.conf ]; then
  echo "on ns1 run:  sudo grep secret /etc/knot/keys.conf"
  read -rsp "paste the secret line or value (hidden) and press enter... " SECRET; echo
  SECRET=$(sed -E 's/.*secret:[[:space:]]*//; s/"//g; s/[[:space:]]//g' <<<"$SECRET")
  [[ $SECRET =~ ^[A-Za-z0-9+/]{43}=$ ]] || { echo "that doesn't look like ns1's key... "; exit 1; }
  printf 'key:\n  - id: xfer-key\n    algorithm: hmac-sha256\n    secret: "%s"\n' "$SECRET" \
    | install -m 640 -o root -g knot /dev/stdin /etc/knot/keys.conf
  unset SECRET
fi
echo "key fingerprint (must match 'sudo md5sum /etc/knot/keys.conf' on ns1)... "
md5sum /etc/knot/keys.conf

## knot config
curl -fsSL "$REPO_RAW/knot_ns2.conf" -o "$TMP/knot.conf"
grep -qE '^[[:space:]]+master:' "$TMP/knot.conf" || { echo "downloaded config is not the ns2 config... "; exit 1; }
install -m 640 -o root -g knot "$TMP/knot.conf" /etc/knot/knot.conf
install -d -m 750 -o knot -g knot /var/lib/knot/zones
knotc -c /etc/knot/knot.conf conf-check

## ns1 + registrar must know this server
IP4=$(curl -fsS -4 https://ifconfig.co 2>/dev/null || echo 'none')
IP6=$(curl -fsS -6 https://ifconfig.co 2>/dev/null || echo 'none')
echo "this server... ipv4: $IP4   ipv6: $IP6"
echo "1) registrar: glue for ns2.$ZONE uses these ips"
echo "2) ns1: remote 'ns2' and acl 'transfer-to-ns2' list these ips, then restart knot on ns1"
read -rp "press enter when both are done... "

## start + wait for the first transfer
systemctl enable knot
systemctl restart knot
echo "waiting for zone transfer from ns1... "
SERIAL=""
for i in {1..30}; do
  SERIAL=$(kdig @127.0.0.1 "$ZONE" SOA +short 2>/dev/null | awk '{print $3}' || true)
  [[ -n $SERIAL ]] && break
  (( i % 10 == 0 )) && knotc zone-refresh "$ZONE" >/dev/null 2>&1 || true
  sleep 2
done
if [[ -n $SERIAL ]]; then
  echo "zone transferred... serial $SERIAL (ns1 should show the same: kdig @$NS1_IP $ZONE SOA +short)"
else
  echo "NO TRANSFER after 60s... check: journalctl -u knot -n 30 --no-pager  (and ns1's log for 'denied')"
fi

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