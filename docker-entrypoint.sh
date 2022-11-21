#!/bin/sh

set -e

if [ -z "${VARNISH_ENTRYPOINT_QUIET_LOGS:-}" ]; then
    exec 3>&1
else
    exec 3>/dev/null
fi

if [ "$1" = "varnishd" ]; then
    if find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
        echo >&3 "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"

        echo >&3 "$0: Looking for shell scripts in /docker-entrypoint.d/"
        find "/docker-entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
            case "$f" in
                *.sh)
                    if [ -x "$f" ]; then
                        echo >&3 "$0: Launching $f";
                        "$f"
                    else
                        # warn on shell scripts without exec bit
                        echo >&3 "$0: Ignoring $f, not executable";
                    fi
                    ;;
                *) echo >&3 "$0: Ignoring $f";;
            esac
        done

        echo >&3 "$0: Configuration complete; ready for start up"
    else
        echo >&3 "$0: No files found in /docker-entrypoint.d/, skipping configuration"
    fi
fi

# this will check if the first argument is a flag
# but only works if all arguments require a hyphenated flag
# -v; -SL; -f arg; etc will work, but not arg1 arg2
if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
    set -- varnishd \
       -j unix,user=${VARNISH_USER:-vcache} \
       -F \
       -f ${VARNISH_CONFIG_FILE:-/etc/varnish/default.vcl} \
       -S ${VARNISH_SECRET_FILE:-/etc/varnish/secret} \
       -a ${VARNISH_LISTEN_HTTP:-":6081"} \
       -T ${VARNISH_MANAGEMENT_INTERFACE:-"localhost:6082"} \
       -s malloc,${VARNISH_MEMORY_SIZE:-256m} \
       -p http_resp_hdr_len=${VARNISH_HTTP_RESP_HDR_LEN:-8k} \
       -p http_resp_size=${VARNISH_HTTP_REQ_SIZE:-32k} \
       -p workspace_backend=${VARNISH_WORKSPACE_BACKEND:-64k} \
       -p thread_pools=${VARNISH_THREAD_POOLS:-2} \
       "$@"
fi

exec "$@"
