#!/usr/bin/env bash

set -e

if [ -z "${PROCESSES_COUNT}" ]
then
    PROCESSES_COUNT=10
fi

if [ -z "${IDLE_TIMEOUT}" ]
then
    IDLE_TIMEOUT=35
fi

if [ -z "${SEND_TIMEOUT}" ]
then
    SEND_TIMEOUT=35
fi

if [ -z "${MEMORY_LIMIT}" ]
then
    MEMORY_LIMIT="256M"
fi

curl_put()
{
    RET=`/usr/bin/curl -s -w '%{http_code}' -X PUT --data-binary @$1 --unix-socket /var/run/control.unit.sock http://localhost/$2`
    RET_BODY=${RET::-3}
    RET_STATUS=$(echo $RET | /usr/bin/tail -c 4)
    if [ "$RET_STATUS" -ne "200" ]; then
        echo "$0: Error: HTTP response status code is '$RET_STATUS'"
        echo "$RET_BODY"
        return 1
    else
        echo "$0: OK: HTTP response status code is '$RET_STATUS'"
        echo "$RET_BODY"
    fi
    return 0
}

config_tpl()
{
    # Workaround because of "permission denied" during sed
    TMP_FILE=/tmp/$(basename $1)
    cp $1 $TMP_FILE

    sed -i "s|{{PROCESSES_COUNT}}|${PROCESSES_COUNT}|" $TMP_FILE
    sed -i "s|{{SEND_TIMEOUT}}|${SEND_TIMEOUT}|" $TMP_FILE
    sed -i "s|{{IDLE_TIMEOUT}}|${IDLE_TIMEOUT}|" $TMP_FILE
    sed -i "s|{{MEMORY_LIMIT}}|${MEMORY_LIMIT}|" $TMP_FILE

    echo "$0: Configuration generated to $TMP_FILE";
    echo "$0: Applying configuration $TMP_FILE";
    curl_put $TMP_FILE "config"
}

if [ "$1" = "unitd" -o "$1" = "unitd-debug" ]; then
    if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -print -quit 2>/dev/null | /bin/grep -q .; then
        echo "$0: /docker-entrypoint.d/ is not empty, launching Unit daemon to perform initial configuration..."
        /usr/sbin/$1 --control unix:/var/run/control.unit.sock

        while [ ! -S /var/run/control.unit.sock ]; do echo "$0: Waiting for control socket to be created..."; /bin/sleep 0.1; done
        # even when the control socket exists, it does not mean unit has finished initialisation
        # this curl call will get a reply once unit is fully launched
        /usr/bin/curl -s -X GET --unix-socket /var/run/control.unit.sock http://localhost/

        echo "$0: Looking for certificate bundles in /docker-entrypoint.d/..."
        for f in $(/usr/bin/find /docker-entrypoint.d/ -type f -name "*.pem"); do
            echo "$0: Uploading certificates bundle: $f"
            curl_put $f "certificates/$(basename $f .pem)"
        done

        echo "$0: Looking for configuration snippets in /docker-entrypoint.d/..."
        for f in $(/usr/bin/find /docker-entrypoint.d/ -type f -name "*.json"); do
            echo "$0: Applying configuration $f";
            curl_put $f "config"
        done

        echo "$0: Looking for configuration templates in /docker-entrypoint.d/..."
        for f in $(/usr/bin/find /docker-entrypoint.d/ -type f -name "*.json.tpl"); do
            echo "$0: Generating configuration $f";
            config_tpl $f
        done

        echo "$0: Looking for shell scripts in /docker-entrypoint.d/..."
        for f in $(/usr/bin/find /docker-entrypoint.d/ -type f -name "*.sh"); do
            echo "$0: Launching $f";
            "$f"
        done

        # warn on filetypes we don't know what to do with
        for f in $(/usr/bin/find /docker-entrypoint.d/ -type f -not -name "*.sh" -not -name "*.json" -not -name "*.json.tpl" -not -name "*.pem"); do
            echo "$0: Ignoring $f";
        done

        echo "$0: Stopping Unit daemon after initial configuration..."
        kill -TERM `/bin/cat /var/run/unit.pid`

        while [ -S /var/run/control.unit.sock ]; do echo "$0: Waiting for control socket to be removed..."; /bin/sleep 0.1; done

        echo
        echo "$0: Unit initial configuration complete; ready for start up..."
        echo
    else
        echo "$0: /docker-entrypoint.d/ is empty, skipping initial configuration..."
    fi
fi

if [ "$1" = "bin/console" -o "$1" = "php" ]; then
    echo "$0: Looking for shell scripts in /docker-entrypoint.d/..."
    for f in $(/usr/bin/find /docker-entrypoint.d/ -type f -name "*.sh"); do
        echo "$0: Launching $f";
        "$f"
    done
fi

exec "$@"
