# Docker Varnish Image

Multi-service (all-in-one) Docker image for [Varnish](https://varnish-cache.org/).

Components included:

- [s6-overlay](https://github.com/just-containers/s6-overlay) as init and process supervisor
- [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter) as Prometheus exporter for Varnish metrics

Varnish modules included:

- [varnish/varnish-modules](https://github.com/varnish/varnish-modules)
- [nigoroll/libvmod-dynamic](github.com/nigoroll/libvmod-dynamic)

Services managed by `s6`:

- `svc-varnishd` - main Varnish daemon
- `svc-varnishncsa` - logging daemon
- `src-varnish-exporter` - metrics exporter for Prometheus

## See also

- [github.com/varnish](https://github.com/varnish)
- [github.com/varnishcache](https://github.com/varnishcache)
- [Varnish Official Image](https://hub.docker.com/_/varnish)
- [varnish/docker-varnish](https://github.com/varnish/docker-varnish)
- [jonnenauha/prometheus_varnish_exporter](https://github.com/jonnenauha/prometheus_varnish_exporter)
- [MooncellWiki/varnish_exporter](https://github.com/MooncellWiki/varnish_exporter)
- [otto-de/prometheus_varnish_exporter](https://github.com/otto-de/prometheus_varnish_exporter)
