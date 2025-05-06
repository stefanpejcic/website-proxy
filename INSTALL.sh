#!/bin/bash

apt-get update -y
apt-get install -y caddy


# FILES
mv html /var/www/html
mv delete_cron.sh /var/www/delete_cron.sh
cd /var/www/html 

systemctl enable --now caddy
mkdir -p /etc/caddy/certs
mv caddy/fullchain.pem  /etc/caddy/certs/fullchain.pem 
mv caddy/privkey.pem /etc/caddy/certs/privkey.pem
mv caddy/Caddyfile /etc/caddy/Caddyfile

service caddy restart
usermod -aG www-data caddy
usermod -aG caddy caddy

# PERMISSIONS
chown -R caddy:caddy /var/www/html/
chmod -R 755 /var/www/html/domains
chmod +x /var/www/delete_cron.sh

# PHP
apt-get install php php-fpm php-cli php-common -y
systemctl start php-fpm
systemctl enable php-fpm

chown caddy:caddy  /run/php-fpm/www.sock
sed -i 's/^user = .*/user = caddy/' /etc/php-fpm.d/www.conf
sed -i 's/^group = .*/group = caddy/' /etc/php-fpm.d/www.conf
service php-fpm restart


# CRON
cron_job="*/5 * * * * bash /var/www/delete_cron.sh"
(crontab -l | grep -q "$cron_job") || (crontab -l; echo "$cron_job") | crontab -

# TEST
# todo:
# php info
# caddy
# domains
# proxy
# curl -s -o /dev/null -w "%{url_effective}\n" -X POST https://preview.openpanel.org/index.php      -d "stefan.openpanel.org" -d "ip=159.223.187.25"
