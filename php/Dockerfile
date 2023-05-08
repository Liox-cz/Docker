FROM php:8.2-cli as UNIT_BUILDER

ARG NGINX_UNIT_VERSION=1.29.1

RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends --no-install-suggests -y ca-certificates git wget build-essential libssl-dev libpcre2-dev \
    && mkdir -p /usr/lib/unit/modules /usr/lib/unit/debug-modules \
    && git clone --depth 1 --branch ${NGINX_UNIT_VERSION} https://github.com/nginx/unit.git \
    && cd unit \
    && NCPU="$(getconf _NPROCESSORS_ONLN)" \
    && DEB_HOST_MULTIARCH="$(dpkg-architecture -q DEB_HOST_MULTIARCH)" \
    && CC_OPT="$(DEB_BUILD_MAINT_OPTIONS="hardening=+all,-pie" DEB_CFLAGS_MAINT_APPEND="-Wp,-D_FORTIFY_SOURCE=2 -fPIC" dpkg-buildflags --get CFLAGS)" \
    && LD_OPT="$(DEB_BUILD_MAINT_OPTIONS="hardening=+all,-pie" DEB_LDFLAGS_MAINT_APPEND="-Wl,--as-needed -pie" dpkg-buildflags --get LDFLAGS)" \
    && CONFIGURE_ARGS="--prefix=/usr \
                --state=/var/lib/unit/state \
                --control=unix:/var/run/control.unit.sock \
                --pid=/var/run/unit.pid \
                --log=/var/log/unit.log \
                --tmp=/var/tmp \
                --openssl \
                --libdir=/usr/lib/$DEB_HOST_MULTIARCH" \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --ld-opt="$LD_OPT" --modules=/usr/lib/unit/debug-modules --debug \
    && make -j $NCPU unitd \
    && ls -la . \
    && ls -la ./build \
    && install -pm755 build/unitd /usr/sbin/unitd-debug \
    && make clean \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --ld-opt="$LD_OPT" --modules=/usr/lib/unit/modules \
    && make -j $NCPU unitd \
    && install -pm755 build/unitd /usr/sbin/unitd \
    && make clean \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --modules=/usr/lib/unit/debug-modules --debug \
    && ./configure php \
    && make -j $NCPU php-install \
    && make clean \
    && ./configure $CONFIGURE_ARGS --cc-opt="$CC_OPT" --modules=/usr/lib/unit/modules \
    && ./configure php \
    && make -j $NCPU php-install \
    && ldd /usr/sbin/unitd | awk '/=>/{print $(NF-1)}' | while read n; do dpkg-query -S $n; done | sed 's/^\([^:]\+\):.*$/\1/' | sort | uniq > /requirements.apt


FROM php:8.2-cli

ENV COMPOSER_MEMORY_LIMIT=-1 \
    COMPOSER_HOME="/.composer" \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    PHP_OPCACHE_MAX_ACCELERATED_FILES=15000 \
    PHP_OPCACHE_MEMORY_CONSUMPTION=192 \
    PHP_OPCACHE_MAX_WASTED_PERCENTAGE=10

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY wait-for-it.sh /usr/local/bin/wait-for-it

# Very convenient PHP extensions installer: https://github.com/mlocati/docker-php-extension-installer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/


COPY --from=UNIT_BUILDER /usr/sbin/unitd /usr/sbin/unitd
COPY --from=UNIT_BUILDER /usr/sbin/unitd-debug /usr/sbin/unitd-debug
COPY --from=UNIT_BUILDER /usr/lib/unit/ /usr/lib/unit/
COPY --from=UNIT_BUILDER /requirements.apt /requirements.apt

RUN chmod +x /usr/local/bin/wait-for-it \
    && mkdir /docker-entrypoint.d/ \
    && mkdir /.composer \
    && mkdir /usr/tmp \
    && apt-get update && apt-get install -y \
        git \
        zip \
        ca-certificates \
        curl \
        lsb-release \
    && install-php-extensions \
        bcmath \
        intl \
        pcntl \
        zip \
        uuid \
        pdo_pgsql \
        opcache \
        apcu \
        gd \
        xdebug \
    && mkdir -p /var/lib/unit/state \
    && apt-get --no-install-recommends --no-install-suggests -y install $(cat /requirements.apt) \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && rm -f /requirements.apt \
    && ln -sf /dev/stdout /var/log/unit.log \
    && ln -sf /dev/stdout /var/log/access.log

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

COPY php.ini /usr/local/etc/php/conf.d/99-php-overrides.ini
COPY config.json.tpl /docker-entrypoint.d/config.json.tpl

STOPSIGNAL SIGTERM

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

CMD ["unitd", "--no-daemon", "--control", "unix:/var/run/control.unit.sock"]
