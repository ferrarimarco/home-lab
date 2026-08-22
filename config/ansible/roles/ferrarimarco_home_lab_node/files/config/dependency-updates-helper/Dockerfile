# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:2.1.2@sha256:a8f9cfa3016237c7008aefa4d9c6639bc9b34d2582eed07ac58dcf56632e4170 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.17.2@sha256:d4351369984d4a9e2a49ac59736f6490856a7ea11f7790040746d21496967010 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2026.8.2@sha256:56690a89c79a0de98035e1719f8324a92d5859c1192ff45adb0230ea81cb42a5 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.11.11.20260606-153911@sha256:aefb67e6a7ff1debdd154a78a7bbb780fd0c873d8639210a7f6a2016ad2b35db AS jellyfin
FROM fallenbagel/jellyseerr:2.7.3@sha256:4538137bc5af902dece165f2bf73776d9cf4eafb6dd714670724af8f3eb77764 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.5.0@sha256:139dfee1c6f89249c8d665d1333a42e8ec74ec0a86bc6bb1c8461e10d3a66a47 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:3.1.0@sha256:2e4cdc7c8d5fa36915f446a29976ee01d3f9cc9722b8530a09121c76fbabef55 AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.5.2@sha256:1295cff29d10b486c0d8324d1559a552140a5932bf8b3d87e398654414f63f92 AS prowlarr
FROM lscr.io/linuxserver/radarr:6.3.0@sha256:a45b5ab0f850f39edb4cc9c95bbd967b52ddc3d4574a4dfb45561177db6c88f4 AS radarr
FROM lscr.io/linuxserver/sonarr:4.0.19@sha256:c19aa4ecdf03d73e1d5c901da33744cb7eb4d921f89bafed1ca264601d7fa224 AS sonarr

# monitoring
FROM ghcr.io/google/cadvisor:v0.60.5@sha256:763aecf1c32c2be8a1a75f9abfc2fc461005c9dbbaa39cb356b354aac1296dbe AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.3.0@sha256:276460d141c732772f8b1fcd785a7de272473e6d39fd85c32b163efc2999cb9a AS nut-exporter
FROM prom/blackbox-exporter:v0.28.0@sha256:e753ff9f3fc458d02cca5eddab5a77e1c175eee484a8925ac7d524f04366c2fc AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.14.0@sha256:5ce7540c3c00ef4ab0c9d2c995c6a5b9c421f44b4a115d97a2c7af3b1c21cbb0 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.12.1@sha256:1b4e4438faca4dd7e001dd445d161a4a2091b0fededa84093b3a8dfeae1f1be0 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:13.0.2@sha256:5dad0df181cb644a14e13617b913b261a54f7d4fd4510721dba420929f35bea2 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl@sha256:212f89e1eaeb2c322d6441b64396e3346026674db8fa9c27beac293405c32b3c AS mosquitto

# network-stack
FROM klutchell/unbound:v1.26.0@sha256:5020cfe1218aeda38777f88279220162e602c3a44efc684550dbf46137106a16 AS unbound
FROM coredns/coredns:1.14.6@sha256:900f9c109f7a33545d3c811516e8376df9019147b750f5ce3e254468769176ea AS coredns
FROM traefik:v3.7.10@sha256:9c3b91d5fb7770853ca5c1124a23c34bf2d9b47ffaebeab2614cbaf410dcb2ac AS traefik

# syncthing
FROM syncthing/syncthing:2.1.3@sha256:8c8ff37ab6aa8be23b700648a90fa9412e214852e9fd6ea8477c8334792daec0 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.2.3@sha256:212b86dff59e3962b4082b5ef20a577e76c8f8527d2ab505cfa887b4bcecb0b0 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.13.0@sha256:4fb4db4d49a217bed6d0204f454ce809febc565bbe051b85c556ee2bcef73d8c AS zigbee2mqtt
