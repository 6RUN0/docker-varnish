# Varnish Docker Image with s6-overlay and Prometheus metrics

Debian-based Docker image for [Varnish Cache](https://varnish-cache.org), supervised by [s6-overlay](https://github.com/just-containers/s6-overlay), with:

- Pre-built **Varnish** from source
- Extra VMODs (e.g. [varnish-modules](https://github.com/varnish/varnish-modules),
  [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic))
- Opinionated defaults for logging and tuning
- Built-in **Prometheus exporter** for [varnishstat](https://varnish-cache.org/docs/trunk/reference/varnishstat.html)
  metrics
- Reproducible build via pinned repositories, commits and checksums

---

## Table of Contents

- [Features](#features)
- [Quick start](#quick-start)
- [Services managed by s6](#services-managed-by-s6)
- [Configuration](#configuration)
- [File system layout & volumes](#file-system-layout--volumes)
- [Updating versions](#updating-versions)
- [Notes & caveats](#notes--caveats)
- [License](#license)
- [See also](#see-also)

This image is designed to be:

- Easy to run in production
- Observable (logs + metrics)
- Configurable via environment variables
- Rebuildable and auditable

---

## Features

- **Debian base**
  Uses a Debian-based image with [s6-overlay](https://github.com/just-containers/s6-overlay)
  as the init system and process supervisor.

- **Varnish built from source**
  Varnish is built from the official source tarball.

- **Extra VMODs**
  Includes commonly used modules such as:
  - [varnish-modules](https://github.com/varnish/varnish-modules)
  - [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic)
  - Additional Varnish utilities from [toolbox](https://github.com/varnish/toolbox)
    and [docker-varnish](https://github.com/varnish/docker-varnish) repositories
    (e.g. example VCLs).

- **Prometheus metrics**
  A [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter) process is included
  and supervised by s6, exposing metrics on a configurable address (default `:9131`).

- **Structured logging**
  [varnishncsa](https://varnish-cache.org/docs/trunk/reference/varnishncsa.html) runs as a separate service,
  using configurable format and filters (e.g. optimized for Loki ingestion).

---

## Quick start

### Build the image

```bash
docker build -t my-varnish .
```

You can override build-time arguments (see [Build-time arguments](#build-time-arguments)):

### Run a container

Minimal example (Varnish listening on host port `6081`):

```bash
docker run --rm \
  -p 6081:6081 \
  my-varnish
```

You will usually mount your own VCL and adjust runtime parameters:

```bash
docker run --rm \
  -p 6081:6081 \
  -v $(pwd)/etc/varnish:/etc/varnish:ro \
  -e VARNISH_CONFIG_FILE=/etc/varnish/default.vcl \
  my-varnish
```

### docker-compose example

```yaml
services:
  varnish:
    image: my-varnish
    container_name: varnish
    restart: unless-stopped
    ports:
      - "6081:6081" # HTTP listener
      - "9131:9131" # Prometheus metrics (varnish_exporter)
    environment:
      # varnishd
      VARNISH_LISTEN_HTTP: ":6081"
      VARNISH_MANAGEMENT_INTERFACE: "127.0.0.1:6082"
      VARNISH_CONFIG_FILE: "/etc/varnish/default.vcl"
      VARNISH_MEMORY_SIZE: "256m"
      # varnishncsa logging
      VARNISHNCSA_FORMAT: "/etc/varnish/log_format_loki"
      VARNISHNCSA_FILTER: "/etc/varnish/log_filter_ge_400"
      # Prometheus exporter
      VARNISH_EXPORTER_LISTEN_ADDRESS: ":9131"
      VARNISH_EXPORTER_TELEMETRY_PATH: "/metrics"
    volumes:
      - ./etc/varnish:/etc/varnish:ro
```

---

## Services managed by s6

The container uses **s6-overlay** to supervise multiple processes:

- **`svc-varnishd`**
  Main Varnish daemon ([varnishd](https://varnish-cache.org/docs/trunk/reference/varnishd.html)), exposes HTTP listener and management port.

- **`svc-varnishncsa`**
  Runs [varnishncsa](https://varnish-cache.org/docs/trunk/reference/varnishncsa.html) in the foreground and ships access logs to stdout/stderr in a configurable format.

- **`svc-varnish-exporter`**
  Runs [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter) for Prometheus metrics, querying [varnishstat](https://varnish-cache.org/docs/trunk/reference/varnishstat.html) from the running Varnish instance.

The services are defined under `rootfs/etc/s6-overlay/s6-rc.d/` and started automatically on container boot.

---

## Configuration

### Build-time arguments

These arguments are used only while building the image (`docker build --build-arg ...`).
For exact defaults and pinned commit hashes, see the `Dockerfile`.

| ARG | Description |
|-----|-------------|
| `DEBIAN_GOLANG_BASE_IMAGE` | Base image used to build [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter) (Go toolchain). |
| `DEBIAN_BASE_IMAGE` | Base image for the final runtime image with [s6-overlay](https://github.com/just-containers/s6-overlay). |
| `VARNISH_VERSION` | Varnish version to build (e.g. `8.0.0`). |
| `VARNISH_REPO_PACKAGE` | Git repo with Debian packaging for Varnish ([pkg-varnish-cache](https://github.com/varnishcache/pkg-varnish-cache)). |
| `VARNISH_REPO_PACKAGE_COMMIT` | Pinned commit of [pkg-varnish-cache](https://github.com/varnishcache/pkg-varnish-cache) for reproducible builds. |
| `VARNISH_DIST_URL` | URL of the Varnish source tarball. |
| `VARNISH_DIST_SHA512` | SHA-512 checksum of the Varnish source tarball. |
| `VARNISH_REPO_ALL_PACKAGER` | Repo for [all-packager](https://github.com/varnish/all-packager) (used to build [varnish-modules](https://github.com/varnish/varnish-modules)). |
| `VARNISH_REPO_ALL_PACKAGER_COMMIT` | Pinned commit of [all-packager](https://github.com/varnish/all-packager). |
| `VARNISH_MODULES_VERSION` | Version of [varnish-modules](https://github.com/varnish/varnish-modules) to build. |
| `VARNISH_MODULES_DIST_URL` | URL of the [varnish-modules](https://github.com/varnish/varnish-modules) source tarball. |
| `VARNISH_MODULES_SHA512SUM` | SHA-512 checksum of the [varnish-modules](https://github.com/varnish/varnish-modules) tarball. |
| `VARNISH_REPO_TOOLBOX` | Repo for Varnish [toolbox](https://github.com/varnish/toolbox) (helper scripts, VCL, etc.). |
| `VARNISH_REPO_TOOLBOX_COMMIT` | Pinned commit of [toolbox](https://github.com/varnish/toolbox). |
| `VMOD_DYNAMIC_REPO` | Repo for [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic). |
| `VMOD_DYNAMIC_REPO_COMMIT` | Pinned commit of [libvmod-dynamic](https://github.com/nigoroll/libvmod-dynamic). |
| `VARNISH_REPO_DOCKER` | Official [docker-varnish](https://github.com/varnish/docker-varnish) repository (default VCL and helpers). |
| `VARNISH_REPO_DOCKER_COMMIT` | Pinned commit of [docker-varnish](https://github.com/varnish/docker-varnish). |
| `VARNISH_EXPORTER_REPO` | Repo of the [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter) project. |
| `VARNISH_EXPORTER_REPO_COMMIT` | Pinned commit of [varnish_exporter](https://github.com/MooncellWiki/varnish_exporter) used for the build. |

> **Tip:** When updating Varnish or VMOD versions, change `*_VERSION` and associated URLs/checksums/commits in a single commit to keep the build reproducible.

---

### Runtime environment – `svc-varnishd` (varnishd)

These variables are read in the `svc-varnishd` service script and mapped to [varnishd](https://varnish-cache.org/docs/trunk/reference/varnishd.html) parameters.

| Variable | Default | Description |
|----------|---------|-------------|
| `VARNISH_CACHE_UID` | `101` | UID for `varnishd` and owner of `/var/lib/varnish` . |
| `VARNISH_GID` | `101` | GID for Varnish processes. |
| `VARNISH_MANAGEMENT_INTERFACE` | `127.0.0.1:6082` | Address/port for the management interface (used by `varnishadm` ). |
| `VARNISH_LISTEN_HTTP` | `:6081` | HTTP listen address for incoming traffic (`-a`). |
| `VARNISH_CONFIG_FILE` | `/etc/varnish/default.vcl` | Main VCL file loaded at startup. |
| `VARNISH_CONNECT_TIMEOUT` | `3.5` | [connect_timeout](https://varnish-cache.org/docs/trunk/reference/varnishd.html#connect-timeout), default connection timeout for backend connections. |
| `VARNISH_HTTP_REQ_HDR_LEN` | `8k` | [http_req_hdr_len](https://varnish-cache.org/docs/trunk/reference/varnishd.html#http-req-hdr-len), maximum length of any HTTP client request header we will allow. |
| `VARNISH_HTTP_RESP_HDR_LEN` | `8k` | [http_resp_hdr_len](https://varnish-cache.org/docs/trunk/reference/varnishd.html#http-resp-hdr-len), maximum length of any HTTP backend response header we will allow. |
| `VARNISH_HTTP_REQ_SIZE` | `32k` | [http_req_size](https://varnish-cache.org/docs/trunk/reference/varnishd.html#http-req-size), maximum number of bytes of HTTP client request we will deal with. |
| `VARNISH_NUKE_LIMIT` | `50` | [nuke_limit](https://varnish-cache.org/docs/trunk/reference/varnishd.html#nuke-limit), maximum number of objects we attempt to nuke in order to make space for a object body.|
| `VARNISH_THREAD_POOLS` | `2` | [thread_pools](https://varnish-cache.org/docs/trunk/reference/varnishd.html#thread-pools), number of worker thread pools. |
| `VARNISH_WORKSPACE_BACKEND` | `96k` | [workspace_backend](https://varnish-cache.org/docs/trunk/reference/varnishd.html#workspace-backend), bytes of HTTP protocol workspace for backend HTTP req/resp. |
| `VARNISH_WORKSPACE_CLIENT` | `96k` | [workspace_client](https://varnish-cache.org/docs/trunk/reference/varnishd.html#workspace-client), bytes of HTTP protocol workspace for clients HTTP req/resp. |
| `VARNISH_WORKSPACE_SESSION` | `0.75k` | [workspace_session](https://varnish-cache.org/docs/trunk/reference/varnishd.html#workspace-session), allocation size for session structure and workspace. |
| `VARNISH_WORKSPACE_THREAD` | `2k` | [workspace_thread](https://varnish-cache.org/docs/trunk/reference/varnishd.html#workspace-thread), bytes of auxiliary workspace per thread. |
| `VARNISH_MEMORY_SIZE` | `256m` | Cache storage size for `-s malloc,<size>`. See [storage backend](https://varnish-cache.org/docs/trunk/reference/varnishd.html#storage-backend) |

All of them can be overridden at container runtime via `docker run -e ...` or `environment:` in `docker-compose.yml`.

---

### Runtime environment – `svc-varnishncsa` (access logs)

The `svc-varnishncsa` service runs [varnishncsa](https://varnish-cache.org/docs/trunk/reference/varnishncsa.html) and streams access logs to stdout/stderr.

| Variable | Default value | Description |
|----------|---------------|-------------|
| `VARNISHLOG_UID` | `102` | UID for the `varnishncsa` process. |
| `VARNISH_GID` | `101` | GID for `varnishncsa` . |
| `VARNISHNCSA_FORMAT` | `/etc/varnish/log_format_loki` | Path to a file with the `varnishncsa` log format string. |
| `VARNISHNCSA_FILTER` | `/etc/varnish/log_filter_ge_400` | Path to a file with `varnishncsa` filter expression. |

You can mount your own format/filter files into `/etc/varnish/` to customize log output, for example to integrate with Loki, ELK, etc.

---

### Runtime environment – `svc-varnish-exporter` (Prometheus exporter)

The `svc-varnish-exporter` service runs a Prometheus exporter that collects stats from the running Varnish instance.

| Variable | Default value | Description |
|----------|---------------|-------------|
| `VARNISHLOG_UID` | `102` | UID for `varnish_exporter`. |
| `VARNISH_GID` | `101` | GID for `varnish_exporter`. |
| `VARNISH_EXPORTER_LISTEN_ADDRESS` | `:9131` | Listen address/port for the exporter HTTP server. |
| `VARNISH_EXPORTER_TELEMETRY_PATH` | `/metrics` | HTTP path for Prometheus metrics. |

To make metrics available outside the container, expose the exporter port:

```yaml
ports:
  - "9131:9131"
```

---

## File system layout & volumes

Key paths inside the container:

- `/etc/varnish` – configuration files, VCLs, log format/filter definitions.
- `/var/lib/varnish` – Varnish storage (malloc indexing, runtime data).
- `/var/log/varnish` – varnishncsa logs (if configured to log to files).

Typical volumes:

```yaml
volumes:
  - ./etc/varnish:/etc/varnish:ro
  - varnish-storage:/var/lib/varnish
  - varnish-logs:/var/log/varnish
```

---

## Updating versions

To update Varnish or any of the VMODs:

1. Edit the relevant `*_VERSION` and URLs/checksums in the `Dockerfile`.
2. Update pinned commits (`*_COMMIT`) of auxiliary repositories if necessary.
3. Rebuild the image:

   ```bash
   docker build -t my-varnish .
   ```

4. Deploy the new image via your usual workflow (Compose, Swarm, Kubernetes, etc.).

---

## Notes & caveats

- The image assumes system users corresponding to `VARNISH_CACHE_UID` / `VARNISHLOG_UID` / `VARNISH_GID`.
  If you override these IDs or mount host directories with specific ownership, make sure UID/GID mapping is correct.
  By default, the following users/groups are created:
  `cat /etc/passwd`:

```text
...
varnish:x:100:101::/nonexistent:/usr/sbin/nologin
vcache:x:101:101::/nonexistent:/usr/sbin/nologin
varnishlog:x:102:101::/nonexistent:/usr/sbin/nologin
```

  `cat /etc/group`:

```text
...
varnish:x:101:
```

- The default configuration is opinionated and optimised for observability.
  Always review `/etc/varnish/default.vcl` and adjust timeouts, caching rules and backends to match your application.

---

## License

This repository does **not** redistribute Varnish or its modules directly.
Refer to the respective upstream projects for licensing details:

- Varnish Cache – <https://varnish-cache.org/>
- varnish-modules – <https://github.com/varnish/varnish-modules>
- libvmod-dynamic – <https://github.com/nigoroll/libvmod-dynamic>
- varnish_exporter – <https://github.com/MooncellWiki/varnish_exporter>

## See also

- [Varnish HTTP Cache](https://varnish-cache.org)
- [Varnish Official Image](https://hub.docker.com/_/varnish)
- [github.com/MooncellWiki/varnish_exporter](https://github.com/MooncellWiki/varnish_exporter)
- [github.com/gquintard](https://github.com/gquintard)
- [github.com/jonnenauha/prometheus_varnish_exporter](https://github.com/jonnenauha/prometheus_varnish_exporter)
- [github.com/otto-de/prometheus_varnish_exporter](https://github.com/otto-de/prometheus_varnish_exporter)
- [github.com/varnish](https://github.com/varnish)
- [github.com/varnishcache](https://github.com/varnishcache)
