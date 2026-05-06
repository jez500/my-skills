---
name: lando
description: Use when adding Lando/Docker to a new project, configuring local dev environments with lando, working on projects that use lando, debugging lando services, writing Dockerfiles, or setting up supervisor-managed entrypoints with cron and queue workers.
---

# Lando — Docker-based Dev Environments

## Overview

Lando is an abstraction over Docker that gives projects a consistent, self-contained dev environment. It handles networking, SSL, proxy routing (`.lndo.site` domains), and service wiring. Configuration lives in `.lando.yml`; the team runs `lando start` and gets everything.

Two separate files serve different purposes:
- `.lando.yml` — local dev environment (Lando only)
- `docker-compose-build.yml` — production/CI image builds (Docker only, no Lando)

## Core Commands

| Command | Description |
|---------|-------------|
| `lando start` | Build and start all services |
| `lando stop` | Stop all services |
| `lando restart` | Restart all services |
| `lando rebuild` | Rebuild images and restart |
| `lando ssh` | Shell into the appserver |
| `lando ssh -s <service>` | Shell into a specific service |
| `lando logs -s <service>` | Tail logs for a service |
| `lando info` | Show URLs, credentials, port mappings |
| `lando poweroff` | Kill all running Lando containers (global) |
| `lando <tooling>` | Run any custom tooling command |

## .lando.yml Structure

```yaml
name: myapp           # short slug, used in URLs: myapp.lndo.site
recipe: laravel       # base recipe (laravel, wordpress, drupal, lamp, lemp, etc.)

config:
  env_file:
    - .env            # expose host .env into containers

# Custom CLI commands run inside containers
tooling:
  artisan:
    service: appserver
    cmd: php artisan
  npm:
    service: appserver
  test:
    service: appserver
    cmd: ./vendor/bin/pest

# Override or add services beyond the recipe
services:
  appserver:
    api: 3
    type: lando
    app_mount: /app
    overrides:
      build:
        context: .
        dockerfile: docker/php.dockerfile
      volumes:
        - .:/app:cached
    services:
      command: /start-app.sh   # entrypoint

# Map services to friendly .lndo.site subdomains
proxy:
  mailhog:
    - mail.myapp.lndo.site
  phpmyadmin:
    - pma.myapp.lndo.site
```

## Custom Dockerfile in Lando

Use `type: lando` with `overrides.build` to swap in your own Dockerfile:

```yaml
services:
  appserver:
    api: 3
    type: lando
    app_mount: /app
    overrides:
      build:
        context: .
        dockerfile: docker/php.dockerfile
      volumes:
        - .:/app:cached
      ports:
        - 3331:3331      # extra ports (Vite HMR, etc.)
    services:
      command: /start-app.sh
    scanner:
      retry: 5           # retries before marking unhealthy
```

## Supervisor Entrypoint Pattern

For apps with background processes (queues, cron), use **supervisord** as PID 1 to manage multiple processes in one container. This keeps cron, queue workers, and the web server all alive.

**`docker/php/start-app.sh`** — bootstraps env, waits for DB, then hands off to supervisord:
```bash
#!/bin/bash
# Copy .env if missing
if [ ! -f ".env" ] || ! grep -q . ".env"; then
    cp .env.example .env
    php artisan key:generate --force
fi

# Ensure storage dirs exist
mkdir -p storage/framework/{sessions,views,testing,cache/data} storage/logs storage/app/public
chmod -R 777 storage

# Wait for the database
while ! nc ${DB_HOST:-database} ${DB_PORT:-3306}; do
  echo "Database unavailable - sleeping"
  sleep 1
done

# Clear and rebuild caches
php artisan config:clear && php artisan optimize:clear
php artisan migrate --force
php artisan optimize && php artisan config:cache && php artisan route:cache

# Hand off to supervisord (manages apache, cron, queue-worker)
supervisord -c /etc/supervisor/conf.d/supervisord.conf
```

**`docker/php/supervisord.conf`** — manages all processes:
```ini
[supervisord]
nodaemon = true
logfile = /dev/null

[program:apache2]
command=apachectl -D "FOREGROUND" -k start
redirect_stderr=true

[program:cron]
command=/start-cron.sh
autostart=true
autorestart=true
user=root
stdout_logfile=/var/log/cron.log
stdout_logfile_maxbytes=0

[program:queue-worker]
command=php artisan queue:work
autostart=true
autorestart=true
redirect_stderr=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
```

**`docker/php/start-cron.sh`**:
```bash
#!/bin/sh
set -e
/usr/bin/crontab /etc/cron.d/schedule-cron
/usr/sbin/cron -f -L 1
```

**`docker/php/schedule-cron`**:
```
* * * * * cd /app && /usr/local/bin/php artisan schedule:run
```

## Dockerfile for PHP + Node (Multi-stage)

```dockerfile
ARG PHP_VERSION=8.4
ARG NODE_VERSION=20

FROM node:${NODE_VERSION}-bookworm-slim AS node
FROM php:${PHP_VERSION}-apache-bookworm

ENV EDITOR=nano
WORKDIR /app

RUN apt update && apt install -y \
    cron supervisor nano zip unzip \
    libzip-dev zlib1g-dev libicu-dev libpq-dev \
    netcat-traditional default-mysql-client less \
    && apt-get clean

RUN docker-php-ext-install exif pcntl posix mysqli pdo pdo_mysql zip intl

# Composer
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer/composer:2-bin /composer /usr/bin/composer

# Node (copy from node stage)
COPY --from=node /usr/lib /usr/lib
COPY --from=node /usr/local/lib /usr/local/lib
COPY --from=node /usr/local/bin /usr/local/bin

COPY . /app
COPY ./docker/php/php.ini    /usr/local/etc/php/conf.d/zzz-php-overrides.ini
COPY ./docker/php/schedule-cron     /etc/cron.d/schedule-cron
COPY ./docker/php/supervisord.conf  /etc/supervisor/conf.d/supervisord.conf
COPY ./docker/php/start-app.sh      /start-app.sh
COPY ./docker/php/start-cron.sh     /start-cron.sh

RUN rm -rf /var/www/html \
    && ln -s /app/public /var/www/html \
    && a2enmod rewrite \
    && chmod 0644 /etc/cron.d/schedule-cron \
    && chmod +x /start-app.sh /start-cron.sh \
    && touch /var/log/cron.log

RUN composer install --no-dev && npm install && npm run build

CMD ["/start-app.sh"]
```

## Adding Common Services

```yaml
services:
  # Separate test database (doesn't pollute dev db)
  tests_db:
    type: laravel-mysql
    creds:
      user: laravel
      password: laravel
      database: laravel

  # phpMyAdmin
  phpmyadmin:
    type: phpmyadmin
    hosts:
      - database
    overrides:
      environment:
        PMA_USER: laravel
        PMA_PASSWORD: laravel

  # Mailhog (catch outbound mail)
  mailhog:
    type: mailhog
    portforward: true
    hogfrom:
      - appserver

  # Meilisearch
  search:
    type: lando
    app_mount: false
    overrides:
      image: getmeili/meilisearch:v1.35
      ports:
        - '7700'
      volumes:
        - ./storage/meilisearch:/meili_data
    services:
      command: ["/bin/meilisearch"]
```

## Custom Tooling Patterns

Multi-command tooling sequences:
```yaml
tooling:
  clear:
    service: appserver
    cmd:
      - rm -f bootstrap/cache/*.php
      - php artisan optimize:clear
      - composer dump-autoload

  seed:
    service: appserver
    cmd:
      - php artisan migrate:fresh --seed
      - php artisan cache:clear

  # Run command on specific service with root user
  xdebug-on:
    cmd:
      - appserver: cp /app/docker/xdebug.ini /usr/local/etc/php/conf.d/ && pkill -USR2 php-fpm || true
    user: root
```

## Lando vs. docker-compose-build.yml

| Concern | File |
|---------|------|
| Local dev (hot reload, tooling, mailhog) | `.lando.yml` |
| Production/CI image builds | `docker-compose-build.yml` |
| Named volumes for build artifacts | `docker-compose-build.yml` |
| `.lndo.site` proxy routing | `.lando.yml` |

The `docker-compose-build.yml` uses YAML anchors (`x-volumes`, `x-environment`) to keep service definitions DRY:
```yaml
x-volumes:
  &default-volumes
  volumes:
    - .:/app:delegated
    - storage:/app/storage

services:
  appserver:
    << : *default-volumes
```

## New Project Setup Checklist

1. Create `.lando.yml` with recipe + env_file
2. Create `docker/php.dockerfile` (or use recipe defaults)
3. Create `docker/php/start-app.sh` with bootstrap + supervisord launch
4. Create `docker/php/supervisord.conf` with all background processes
5. Create `docker/php/schedule-cron` with cron schedule
6. Create `docker/php/start-cron.sh`
7. Add `.lando.yml` to `.gitignore` if team-specific, otherwise commit it
8. Run `lando start` — check `lando info` for URLs

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| `app_mount` path wrong | Match the `WORKDIR` in your Dockerfile |
| Scanner fails immediately | Add `scanner: retry: 5` to the service |
| Cron not firing | Verify file perms: `chmod 0644 /etc/cron.d/*` |
| Queue worker exits | Add `autorestart=true` in supervisord |
| Port conflicts | Check with `lando info`, adjust `ports` in overrides |
| `lando rebuild` slow | Use `lando rebuild -s appserver` to target one service |

## See Also

- Full example files: `examples/` directory alongside this skill
- Official docs: https://lando.dev/docs
