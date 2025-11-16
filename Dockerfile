ARG DEBIAN_GOLANG_BASE_IMAGE=golang:1.25-trixie
ARG DEBIAN_BASE_IMAGE=6run0/s6-overlay:debian


FROM ${DEBIAN_GOLANG_BASE_IMAGE} AS varnish-exporter-builder

ARG VARNISH_EXPORTER_REPO=https://github.com/MooncellWiki/varnish_exporter.git
ARG VARNISH_EXPORTER_REPO_COMMIT=0d7fb94896cc845771c7f49d0916fa6f5d35336c

WORKDIR /src

RUN \
  set -eux; \
  # Helper function to clone a specific git commit
  # x_git_clone <repo_url> <commit_hash>
  x_git_clone() { \
  git init -b main .; \
  git remote add origin "$1";\
  git fetch --depth 1 origin "$2"; \
  git checkout -b "x-git-clone-$2" FETCH_HEAD; \
  }; \
  x_git_clone "${VARNISH_EXPORTER_REPO}" "${VARNISH_EXPORTER_REPO_COMMIT}"; \
  go build \
  -mod=readonly \
  -trimpath \
  -ldflags "-s -w" \
  -buildvcs=false \
  -o /varnish_exporter . \
  ; \
  chmod +x /varnish_exporter;

#
# The final image
#
FROM ${DEBIAN_BASE_IMAGE}

# Links:
#  - https://github.com/varnish
#  - https://github.com/varnishcache
#  - https://varnish-cache.org
# Varnish arguments
ARG VARNISH_REPO_PACKAGE=https://github.com/varnishcache/pkg-varnish-cache.git
ARG VARNISH_REPO_PACKAGE_COMMIT=a28bede7b075cd52b0989e4d8fd0e4a601e410ef
ARG VARNISH_VERSION=8.0.0
ARG VARNISH_DIST_URL=https://varnish-cache.org/downloads/varnish-${VARNISH_VERSION}.tgz
ARG VARNISH_DIST_SHA512=c381928e23deaacb863dcf389a494f30a56d22a4e88fe0c5dc7d4a93828f3dc0595c7ae41837f3549795828aca1a30e08f4456d4a752a6d12c19b61943dd99e9
# Varnish modules arguments
ARG VARNISH_REPO_ALL_PACKAGER=https://github.com/varnish/all-packager.git
ARG VARNISH_REPO_ALL_PACKAGER_COMMIT="5d4e84bb32696c1d08aaf36e2602f51864ca804c"
ARG VARNISH_MODULES_VERSION=0.27.0
ARG VARNISH_MODULES_SHA512SUM=bb8a55b3d665fe6de918f784a6f4276b2053f5b1cd0628d6b6c6c78c0042fd678736a2f48375cf356daa47a987175f52569c0b468ccd2b37ab55a32c25255264
ARG VARNISH_MODULES_DIST_URL=https://github.com/varnish/varnish-modules/releases/download/${VARNISH_MODULES_VERSION}/varnish-modules-${VARNISH_MODULES_VERSION}.tar.gz
# Varnish toolbox arguments
ARG VARNISH_REPO_TOOLBOX=https://github.com/varnish/toolbox.git
ARG VARNISH_REPO_TOOLBOX_COMMIT=aa24ceb1869def5c1b0a1772e98b60926206ccc2
# Libvmod-dynamic arguments
ARG VMOD_DYNAMIC_REPO=https://github.com/nigoroll/libvmod-dynamic.git
ARG VMOD_DYNAMIC_REPO_COMMIT=83544fd7d2a307c15e90d807067b381c75c93540
# Official docker image arguments
ARG VARNISH_REPO_DOCKER=https://github.com/varnish/docker-varnish.git
ARG VARNISH_REPO_DOCKER_COMMIT=fce641d80febcd8fc8fad941d721318e3aa95aba

RUN \
  set -eux; \
  export DEBIAN_FRONTEND=noninteractive; \
  export DEBCONF_NONINTERACTIVE_SEEN=true; \
  apt-get update; \
  # Save current manually installed packages
  saved_apt_mark="$(apt-mark showmanual)"; \
  apt-get install -y --no-install-recommends --no-install-suggests \
  adduser \
  apt-utils \
  curl \
  debhelper \
  devscripts \
  dpkg-dev \
  equivs \
  fakeroot \
  git \
  libgetdns-dev \
  libgetdns10t64 \
  netbase \
  pkg-config \
  ; \
  # Helper function to clone a specific git commit
  # x_git_clone <repo_url> <commit_hash>
  x_git_clone() { \
  git init -b main .; \
  git remote add origin "$1";\
  git fetch --depth 1 origin "$2"; \
  git checkout -b "x-git-clone-$2" FETCH_HEAD; \
  }; \
  # Helper function to fetch, verify and unpack an archive
  # x_fetch_unpack <url> <sha512sum>
  x_fetch_unpack() { \
  curl -fsSL -o orig.tgz "$1"; \
  echo "$2 orig.tgz" | sha512sum -c -; \
  tar xavf orig.tgz --strip 1; \
  }; \
  # Base working directory
  # Note: used to keep all temporary working directories together for easier cleanup
  base_workdir=$(mktemp -d /workdir-XXXXXX); \
  # Fix permission for test passing
  chmod a+rX "${base_workdir}"; \
  # Helper function to create and use a temporary working directory
  # x_use_workdir <name_prefix>
  x_use_workdir() { \
  __tmp_workdir=$(mktemp -d "${base_workdir}/$1-XXXXXX"); \
  # Fix permission for test passing
  chmod a+rX "${__tmp_workdir}"; \
  cd "${__tmp_workdir}"; \
  }; \
  # The package pool
  package_pool=$(mktemp -d "${base_workdir}/package-XXXXXX"); \
  #
  # Build varnish package
  #
  x_use_workdir varnish; \
  x_git_clone "${VARNISH_REPO_PACKAGE}" "${VARNISH_REPO_PACKAGE_COMMIT}"; \
  x_fetch_unpack "${VARNISH_DIST_URL}" "${VARNISH_DIST_SHA512}"; \
  sed -i -e "s|@VERSION@|$VARNISH_VERSION|" "debian/changelog"; \
  mk-build-deps --install --tool="apt-get -o Debug::pkgProblemResolver=yes --yes" debian/control; \
  dpkg-buildpackage -us -uc -j"$(nproc)"; \
  apt-get -y --no-install-recommends --no-install-suggests install ../varnish*.deb; \
  mv ../varnish*.deb "${package_pool}/"; \
  #
  # Build varnish-modules package
  #
  x_use_workdir varnish-modules; \
  x_git_clone "${VARNISH_REPO_ALL_PACKAGER}" "${VARNISH_REPO_ALL_PACKAGER_COMMIT}"; \
  cd varnish-modules; \
  sed -i \
  -e "s|@VVERSION@|$VARNISH_VERSION|" \
  -e "s|@PVERSION@|$VARNISH_MODULES_VERSION|" \
  debian/* ; \
  x_fetch_unpack ${VARNISH_MODULES_DIST_URL} ${VARNISH_MODULES_SHA512SUM}; \
  mk-build-deps --install --tool="apt-get -o Debug::pkgProblemResolver=yes --yes" debian/control; \
  dpkg-buildpackage -us -uc -j"$(nproc)"; \
  mv ../varnish-modules*.deb "${package_pool}/"; \
  #
  # Build libvmod-dynamic package
  #
  x_use_workdir libvmod-dynamic; \
  x_git_clone "${VMOD_DYNAMIC_REPO}" "${VMOD_DYNAMIC_REPO_COMMIT}"; \
  ./bootstrap; \
  make -j"$(nproc)"; \
  make check; \
  make install; \
  #
  # Install built packages
  #
  cd "${package_pool}"; \
  # Restore saved manually installed packages
  apt-mark auto '.*' > /dev/null; \
  [ -z "$saved_apt_mark" ] || apt-mark manual "$saved_apt_mark" > /dev/null; \
  rm -f varnish-dev*.deb; \
  dpkg -i ./*.deb; \
  apt-get install -y --no-install-recommends --no-install-suggests \
  # Required by libvmod-dynamic
  libgetdns10t64 \
  # Used by health probes
  curl \
  ; \
  apt-mark hold varnish varnish-modules; \
  #
  # Install varnish toolbox
  #
  x_use_workdir toolbox; \
  x_git_clone "${VARNISH_REPO_TOOLBOX}" "${VARNISH_REPO_TOOLBOX_COMMIT}"; \
  cp vcls/verbose_builtin/verbose_builtin.vcl /etc/varnish/; \
  cp vcls/hit-miss/hit-miss.vcl /etc/varnish/; \
  #
  # Install default varnish docker files
  #
  x_use_workdir docker-varnish; \
  x_git_clone "${VARNISH_REPO_DOCKER}" "${VARNISH_REPO_DOCKER_COMMIT}"; \
  cp fresh/debian/default.vcl /etc/varnish/; \
  #
  # Cleanup
  #
  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
  apt-get autoclean -y; \
  rm -rf \
  "${base_workdir}" \
  /var/cache/apt/archives/* \
  /var/lib/apt/lists/* \
  /var/log/alternatives.log \
  /var/log/apt* \
  /var/log/dpkg.log \
  ;

COPY rootfs/ /
COPY --from=varnish-exporter-builder /varnish_exporter /usr/local/bin/varnish_exporter

EXPOSE 6081 9131
