FROM php:8.3-fpm

RUN apt-get update && apt-get install -y \
        libpq-dev \
        libzip-dev \
        libpng-dev \
        unzip \
        gettext-base \
        postgresql-client \
    && docker-php-ext-install pdo_pgsql pgsql bcmath pcntl zip gd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY infra/docker/php/www.conf.template /etc/php-fpm.d/www.conf.template
COPY infra/docker/php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
CMD ["php-fpm"]
