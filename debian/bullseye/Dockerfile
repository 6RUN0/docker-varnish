# vim:set ft=dockerfile:
FROM debian:bullseye-slim

RUN \
	set -eux; \
# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
	groupadd -r varnish && \
	useradd -r -d /nonexistent -M -s /usr/sbin/nologin -g varnish varnish && \
	useradd -r -d /nonexistent -M -s /usr/sbin/nologin -g varnish vcache && \
	useradd -r -d /nonexistent -M -s /usr/sbin/nologin -g varnish varnishlog; \
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
# Install varnish package
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends varnish varnish-modules; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	rm -rf /var/cache/apt/archives/*; \
        varnishd -V; \
# create a docker-entrypoint.d directory
        mkdir /docker-entrypoint.d

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 6081

CMD []
