FROM alpine:latest

RUN \
  set -eux; \
  apk upgrade --no-cache; \
  apk add --no-cache --upgrade \
  su-exec \
  tini \
  varnish \
  ;

COPY . /

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]

EXPOSE 6081

CMD []
