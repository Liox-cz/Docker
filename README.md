# Liox Docker base images

Images are built automatically using Github actions and pushed to Github Container Registry (ghcr.io).

Purpose of this repository is to speed up builds of other images. This approach is typically called "base images".

## PHP

```
ghcr.io/liox-cz/php:8.2
```

Contains:
- Composer 2
- Xdebug
- Docker
- [mlocati/php-extension-installer](https://github.com/mlocati/docker-php-extension-installer)

To unload xdebug:
`/usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini`
