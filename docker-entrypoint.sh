#!/bin/sh

set -e

if [ -z "${VARNISH_ENTRYPOINT_QUIET_LOGS:-}" ]; then
  exec 3>&1
else
  exec 3>/dev/null
fi

if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
  if find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
    echo >&3 "$0: /docker-entrypoint.d/ is not empty, will attempt to perform configuration"

    echo >&3 "$0: Looking for shell scripts in /docker-entrypoint.d/"
    find "/docker-entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
      case "$f" in
      *.sh)
        if [ -x "$f" ]; then
          echo >&3 "$0: Launching $f"
          "$f"
        else
          # warn on shell scripts without exec bit
          echo >&3 "$0: Ignoring $f, not executable"
        fi
        ;;
      *) echo >&3 "$0: Ignoring $f" ;;
      esac
    done

    echo >&3 "$0: Configuration complete; ready for start up"
  else
    echo >&3 "$0: No files found in /docker-entrypoint.d/, skipping configuration"
  fi
  # see https://varnish-cache.org/docs/trunk/reference/varnishd.html#list-of-parameters
  set -- varnishd \
    -F \
    -T ${VARNISH_MANAGEMENT_INTERFACE:-"127.0.0.1:6082"} \
    -a ${VARNISH_LISTEN_HTTP:-":6081"} \
    -f ${VARNISH_CONFIG_FILE:-/etc/varnish/default.vcl} \
    -j unix,user=${VARNISH_USER:-varnish} \
    -p connect_timeout=${VARNISH_CONNECT_TIMEOUT:-3.5} \
    -p http_req_hdr_len=${VARNISH_HTTP_REQ_HDR_LEN:-8k} \
    -p http_resp_hdr_len=${VARNISH_HTTP_RESP_HDR_LEN:-8k} \
    -p http_resp_size=${VARNISH_HTTP_REQ_SIZE:-32k} \
    -p nuke_limit=${VARNISH_NUKE_LIMIT:-50} \
    -p thread_pools=${VARNISH_THREAD_POOLS:-2} \
    -p workspace_backend=${VARNISH_WORKSPACE_BACKEND:-96k} \
    -p workspace_client=${VARNISH_WORKSPACE_CLIENT:-96k} \
    -p workspace_session=${VARNISH_WORKSPACE_SESSION:-0.75k} \
    -p workspace_thread=${VARNISH_WORKSPACE_THREAD:-2k} \
    -s malloc,${VARNISH_MEMORY_SIZE:-256m} \
    "$@"
fi

exec "$@"
