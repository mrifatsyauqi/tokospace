#!/bin/sh
set -eu

: "${PHP_FPM_MAX_CHILDREN:=4}"

envsubst '${PHP_FPM_MAX_CHILDREN}' \
  < /etc/php-fpm.d/www.conf.template \
  > /etc/php-fpm.d/www.conf

exec "$@"
