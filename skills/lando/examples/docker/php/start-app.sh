#!/bin/bash

# Setup the environment file if it doesn't exist.
if [ ! -f ".env" ] || ! grep -q . ".env" ; then
    cp .env.example .env
    php artisan key:generate --force
fi

# Debugging
printenv

# Ensure storage exists
mkdir -p storage/framework/sessions \
    && mkdir -p storage/framework/views \
    && mkdir -p storage/framework/testing \
    && mkdir -p storage/logs \
    && mkdir -p storage/app/public \
    && chmod -R 777 storage

# Setup storage and clear caches
php artisan storage:link
php artisan config:clear
php artisan optimize:clear
php artisan view:clear

# Wait for the database
while ! nc ${DB_HOST:-database} ${DB_PORT:-3306}; do
  >&2 echo "Database unavailable - sleeping"
  sleep 1
done

# Cache it all
php artisan cache:clear
php artisan optimize
php artisan config:cache
php artisan route:cache
php artisan event:cache
php artisan view:cache

# Run migrations
php artisan migrate --force

# Start supervisor that handles cron, queue workers, and apache.
supervisord -c /etc/supervisor/conf.d/supervisord.conf
