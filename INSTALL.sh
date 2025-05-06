#!/bin/bash

set -euo pipefail

log() {
    echo "[INFO] $1"
}

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Update and install Caddy if not already installed
log "Updating apt packages"
apt-get update -y

if ! command -v caddy &>/dev/null; then
    log "Installing Caddy"
    apt-get install -y caddy
else
    log "Caddy is already installed"
fi

# Create required directories
log "Setting up file structure"
mkdir -p /var/www/html /etc/caddy/certs

# Move files (only if they exist)
[ -d html ] && mv html/* /var/www/html/ || log "No 'html' folder found"
[ -f delete_cron.sh ] && mv delete_cron.sh /var/www/delete_cron.sh || log "No delete_cron.sh found"

# Caddy Configuration
if [ -d caddy ]; then
    [ -f caddy/fullchain.pem ] && mv caddy/fullchain.pem /etc/caddy/certs/
    [ -f caddy/privkey.pem ] && mv caddy/privkey.pem /etc/caddy/certs/
    [ -f caddy/Caddyfile ] && mv caddy/Caddyfile /etc/caddy/Caddyfile
else
    log "No 'caddy' directory found"
fi

log "Enabling and restarting Caddy"
systemctl enable --now caddy || error_exit "Failed to enable/start Caddy"
service caddy restart || error_exit "Failed to restart Caddy"

# Add user to groups
log "Adding 'caddy' user to groups"
usermod -aG www-data caddy || log "Group 'www-data' may not exist"
usermod -aG caddy caddy || true

# Set correct permissions
log "Setting permissions"
chown -R caddy:caddy /var/www/html/ /var/www || true
chmod -R 755 /var/www/html/domains || true
[ -f /var/www/delete_cron.sh ] && chmod +x /var/www/delete_cron.sh

# PHP Installation
log "Installing PHP 8.3 and extensions"
apt-get install -y php8.3-fpm php8.3-curl php8.3-common

systemctl enable --now php8.3-fpm || error_exit "Failed to start/enable PHP-FPM"

# PHP-FPM Pool Configuration
log "Configuring PHP-FPM to run as caddy"
sed -i 's/^user = .*/user = caddy/' /etc/php/8.3/fpm/pool.d/www.conf
sed -i 's/^group = .*/group = caddy/' /etc/php/8.3/fpm/pool.d/www.conf

systemctl daemon-reexec
systemctl restart php8.3-fpm || error_exit "Failed to restart PHP-FPM"

# Adjust PHP socket permissions
chown caddy:caddy /run/php/php8.3-fpm.sock || true
chown -R caddy:caddy /etc/php || true

# CRON Setup
log "Configuring cron job"
cron_job="*/5 * * * * bash /var/www/delete_cron.sh"
(crontab -l 2>/dev/null | grep -F "$cron_job") || (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
#crontab -l | sort | uniq | crontab -


log "Setup complete!"



: '

# TODO:
- test php
- change cf a record
- notify on success

# DEBUG:

curl -X POST https://preview.openpanel.org/index.php \
  -d "domain=example.com" \
  -d "ip=1.2.3.4" \
  -i


# TEST: curl -s -o /dev/null -w "%{redirect_url}\n" -X POST https://preview.openpanel.org/index.php -d "domain=example.com" -d "ip=1.2.3.4"

'
