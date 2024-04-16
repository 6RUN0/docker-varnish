FROM alpine:latest

RUN \
    set -eux; \
    apk upgrade --no-cache; \
    apk add --no-cache --upgrade \
        varnish \
        tini \
        ;

COPY . /

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

EXPOSE 6081

CMD []
