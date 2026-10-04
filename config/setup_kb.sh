#!/usr/bin/env bash
# kanboard at https://toprakkilic.com/kanboard/
set -euo pipefail

VERSION=1.2.54

# php
apt install -y php8.4-fpm php8.4-cli php8.4-gd php8.4-mbstring php8.4-xml php8.4-sqlite3 php8.4-curl php8.4-opcache

# code
rm -rf /srv/www/kanboard
curl -fsSL "https://github.com/kanboard/kanboard/archive/refs/tags/v$VERSION.tar.gz" | tar xz -C /srv/www/
mv "/srv/www/kanboard-$VERSION" /srv/www/kanboard
chown -R root:root /srv/www/kanboard

# data
install -d -m 750 -o www-data -g www-data /var/lib/kanboard
echo "<?php define('DATA_DIR', '/var/lib/kanboard');" > /srv/www/kanboard/config.php

# set user admin password on first run
if [ ! -f /var/lib/kanboard/db.sqlite ]; then
  cd /srv/www/kanboard && sudo -u www-data php cli user:reset-password admin
fi

# daily cronjob (overdue notifications, stats)
echo "0 8 * * * www-data cd /srv/www/kanboard && php cli cronjob >/dev/null 2>&1" > /etc/cron.d/kanboard

# restart php so it drops cached code from the old version
systemctl restart php8.4-fpm


echo "done... https://toprakkilic.com/kanboard/"