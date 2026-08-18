#!/bin/sh
set -eu

: "${PHP_FPM_MAX_CHILDREN:=4}"

envsubst '${PHP_FPM_MAX_CHILDREN}' \
  < /etc/php-fpm.d/www.conf.template \
  > /etc/php-fpm.d/www.conf

# apps/api is bind-mounted, not baked into the image, so a fresh clone (no
# host-side `composer install` yet) would otherwise boot with no vendor/ at
# all and every request would 500 on the missing autoloader.
if [ ! -f /var/www/html/vendor/autoload.php ]; then
  echo "vendor/autoload.php missing — running composer install..."
  composer install --no-interaction --no-progress
fi

exec "$@"
