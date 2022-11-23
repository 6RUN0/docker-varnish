#!/bin/sh

set -e

if [ -z "$VARNISHNCSA_ENABLE" ]; then
    exit 0
fi

VARNISHLOG="gosu vcache varnishncsa"

VARNISHNCSA_FORMAT=${VARNISHNCSA_FORMAT:-/etc/varnish/log_format}
VARNISHNCSA_FILTER=${VARNISHNCSA_FILTER:-/etc/varnish/log_filter}

if [ -r "$VARNISHNCSA_FORMAT" ]; then
    VARNISHLOG="$VARNISHLOG -f $VARNISHNCSA_FORMAT"
fi

if [ -r "$VARNISHNCSA_FILTER" ]; then
    VARNISHLOG="$VARNISHLOG -Q $VARNISHNCSA_FILTER"
fi

$VARNISHLOG &
