# vim:set ft=dockerfile:
FROM debian:bullseye-slim

RUN \
	set -eux; \
# add our user and group first to make sure their IDs get assigned consistently, regardless of whatever dependencies get added
	groupadd -r varnish && \
	useradd -r -d /nonexistent -M -s /usr/sbin/nologin -g varnish varnish && \
	useradd -r -d /nonexistent -M -s /usr/sbin/nologin -g varnish vcache && \
	useradd -r -d /nonexistent -M -s /usr/sbin/nologin -g varnish varnishlog; \
# grab gosu for easy step-down from root
# https://github.com/tianon/gosu/releases
	savedAptMark="$(apt-mark showmanual)"; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates dirmngr gnupg wget tar gzip; \
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/latest/download/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/latest/download/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	chmod +x /usr/local/bin/gosu; \
	gosu --version; \
	gosu nobody true; \
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark > /dev/null; \
# Install varnish package
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends varnish varnish-modules tini; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	rm -rf /var/cache/apt/archives/*; \
        varnishd -V; \
# create a docker-entrypoint.d directory
        mkdir /docker-entrypoint.d

COPY docker-entrypoint.sh /
COPY varnish-log.sh /docker-entrypoint.d/

ENTRYPOINT ["tini", "--"]

EXPOSE 6081

CMD ["/docker-entrypoint.sh"]
