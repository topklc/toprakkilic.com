#!/usr/bin/env bash
# Deploy Knot DNS config. Run as: sudo bash config/deploy.sh
set -euo pipefail

REPO=/srv/www/toprakkilic.com
KEYS=/etc/knot/keys.conf

if [ "$(id -u)" -ne 0 ]; then
    echo "run with sudo" >&2
    exit 1
fi

if [ ! -s "$KEYS" ]; then
    umask 027
    printf 'key:\n  - id: xfer-key\n    algorithm: hmac-sha256\n    secret: "%s"\n' \
        "$(head -c 32 /dev/urandom | base64)" > "$KEYS"
    chown root:knot "$KEYS"
    chmod 640 "$KEYS"
    echo "generated $KEYS"
fi

cp "$REPO/config/knot.conf" /etc/knot/knot.conf
install -D -m 640 -o knot -g knot \
    "$REPO/config/toprakkilic.com.zone" /var/lib/knot/zones/toprakkilic.com.zone

KZC=$(command -v kzonecheck || dpkg -L knot knot-dnsutils 2>/dev/null | grep -m1 '/kzonecheck$' || true)
if [ -n "$KZC" ]; then
    "$KZC" -o toprakkilic.com /var/lib/knot/zones/toprakkilic.com.zone
else
    echo "kzonecheck not found - relying on knotd semantic checks on load"
fi

knotc conf-check
systemctl enable knot
# restart, not reload: server.listen only binds at startup
systemctl restart knot
sleep 1
systemctl --no-pager status knot
knotc zone-status toprakkilic.com
