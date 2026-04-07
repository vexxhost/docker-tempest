# SPDX-FileCopyrightText: © 2025 VEXXHOST, Inc.
# SPDX-License-Identifier: GPL-3.0-or-later

FROM golang AS octavia-test-server
RUN --mount=type=bind,from=octavia-tempest-plugin,source=/,target=/src <<EOF
GO111MODULE=off CGO_ENABLED=0 GOOS=linux go build \
    -a -ldflags '-s -w -extldflags -static' \
    -o /build/test_server.bin \
    /src/octavia_tempest_plugin/contrib/test_server/test_server.go
EOF

FROM ghcr.io/vexxhost/openstack-venv-builder:main@sha256:9bc038acdce3eda5ba4cc2756ba5e62d35f51ba08f4d9b2723330be96f5832fe AS build
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

FROM ghcr.io/vexxhost/python-base:main@sha256:26bf247ae79a9f5582bf7a07d14852cb85b2757538c868eb979b7d7f8af81a80
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
