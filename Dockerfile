# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM golang AS octavia-test-server
RUN --mount=type=bind,from=octavia-tempest-plugin,source=/,target=/src <<EOF
GO111MODULE=off CGO_ENABLED=0 GOOS=linux go build \
    -a -ldflags '-s -w -extldflags -static' \
    -o /build/test_server.bin \
    /src/octavia_tempest_plugin/contrib/test_server/test_server.go
EOF

FROM ghcr.io/vexxhost/openstack-venv-builder:main@sha256:a2e0e96c4c115f87f57dea53548e3514453e6ff4ba027d49e7cd70b5900a21ea AS build
RUN \
  --mount=type=bind,from=requirements,source=/,target=/src/requirements,readwrite \
  --mount=type=bind,from=tempest,source=/,target=/src/tempest,readwrite \
  --mount=type=bind,from=barbican-tempest-plugin,source=/,target=/src/barbican-tempest-plugin,readwrite \
  --mount=type=bind,from=cinder-tempest-plugin,source=/,target=/src/cinder-tempest-plugin,readwrite \
  --mount=type=bind,from=heat-tempest-plugin,source=/,target=/src/heat-tempest-plugin,readwrite \
  --mount=type=bind,from=keystone-tempest-plugin,source=/,target=/src/keystone-tempest-plugin,readwrite \
  --mount=type=bind,from=neutron-tempest-plugin,source=/,target=/src/neutron-tempest-plugin,readwrite \
  --mount=type=bind,from=octavia-tempest-plugin,source=/,target=/src/octavia-tempest-plugin,readwrite <<EOF bash -xe
uv pip install \
    --constraint /src/requirements/upper-constraints.txt \
        /src/tempest \
        /src/barbican-tempest-plugin \
        /src/cinder-tempest-plugin \
        /src/heat-tempest-plugin \
        /src/keystone-tempest-plugin \
        /src/neutron-tempest-plugin \
        /src/octavia-tempest-plugin
EOF

FROM ghcr.io/vexxhost/python-base:main@sha256:56b0f81490bfe511a450d192cd825c7e2e0d47055b594f420ece0d3830812055
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
