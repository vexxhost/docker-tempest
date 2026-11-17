# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM golang@sha256:205c7636d74e0ffbe3d007162df7d74f859f5a8c8322dfb9f907977686c126cf AS octavia-test-server
RUN --mount=type=bind,from=octavia-tempest-plugin,source=/,target=/src <<EOF
GO111MODULE=off CGO_ENABLED=0 GOOS=linux go build \
    -a -ldflags '-s -w -extldflags -static' \
    -o /build/test_server.bin \
    /src/octavia_tempest_plugin/contrib/test_server/test_server.go
EOF

FROM ghcr.io/vexxhost/openstack-venv-builder:main@sha256:9fbb1acf75178dce2934f73fbbe6c5d3e8c2191689251764da04172faa76cbf1 AS build
RUN \
  --mount=type=bind,from=tempest,source=/,target=/src/tempest,readwrite \
  --mount=type=bind,from=barbican-tempest-plugin,source=/,target=/src/barbican-tempest-plugin,readwrite \
  --mount=type=bind,from=cinder-tempest-plugin,source=/,target=/src/cinder-tempest-plugin,readwrite \
  --mount=type=bind,from=heat-tempest-plugin,source=/,target=/src/heat-tempest-plugin,readwrite \
  --mount=type=bind,from=keystone-tempest-plugin,source=/,target=/src/keystone-tempest-plugin,readwrite \
  --mount=type=bind,from=neutron-tempest-plugin,source=/,target=/src/neutron-tempest-plugin,readwrite \
  --mount=type=bind,from=octavia-tempest-plugin,source=/,target=/src/octavia-tempest-plugin,readwrite <<EOF bash -xe
uv pip install \
    --constraint /upper-constraints.txt \
        /src/tempest \
        /src/barbican-tempest-plugin \
        /src/cinder-tempest-plugin \
        /src/heat-tempest-plugin \
        /src/keystone-tempest-plugin \
        /src/neutron-tempest-plugin \
        /src/octavia-tempest-plugin
EOF

FROM ghcr.io/vexxhost/python-base:main@sha256:a3028101248a25358d16549a4fdbf65826a5ebfd04d91a5e2da2f2b48b07ad68
RUN \
    groupadd -g 42424 tempest && \
    useradd -u 42424 -g 42424 -M -d /var/lib/tempest -s /usr/sbin/nologin -c "Tempest User" tempest && \
    mkdir -p /etc/tempest /var/log/tempest /var/lib/tempest /var/cache/tempest && \
    chown -Rv tempest:tempest /etc/tempest /var/log/tempest /var/lib/tempest /var/cache/tempest
RUN <<EOF bash -xe
apt-get update -qq
apt-get install -qq -y --no-install-recommends \
    iputils-ping openssh-client
apt-get clean
rm -rf /var/lib/apt/lists/*
EOF
COPY --from=octavia-test-server --link /build/test_server.bin /opt/octavia-tempest-plugin/test_server.bin
COPY --from=build --link /var/lib/openstack /var/lib/openstack
