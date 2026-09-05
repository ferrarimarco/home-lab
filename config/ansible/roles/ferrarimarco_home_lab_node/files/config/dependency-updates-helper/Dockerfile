# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:2.1.2@sha256:a8f9cfa3016237c7008aefa4d9c6639bc9b34d2582eed07ac58dcf56632e4170 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.17.2@sha256:d4351369984d4a9e2a49ac59736f6490856a7ea11f7790040746d21496967010 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2026.8.3@sha256:14931c6b13756317849f46da1d01b45937a1150db66c081cfe529d48215943fe AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.11.11.20260606-153911@sha256:aefb67e6a7ff1debdd154a78a7bbb780fd0c873d8639210a7f6a2016ad2b35db AS jellyfin
FROM fallenbagel/jellyseerr:2.7.3@sha256:4538137bc5af902dece165f2bf73776d9cf4eafb6dd714670724af8f3eb77764 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.5.0@sha256:139dfee1c6f89249c8d665d1333a42e8ec74ec0a86bc6bb1c8461e10d3a66a47 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:3.1.0@sha256:c74c32408fdf6e7926ad62641fc1a5544206ee65c33f2188bb179edb30e28f5a AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.5.2@sha256:91844fa2c927ad6ede5630127183cc7868b175f6223e83e6a5da1fffea2aa782 AS prowlarr
FROM lscr.io/linuxserver/radarr:6.3.0@sha256:119aaa4a4f7349bcd2a136c5373a0d7925b5479915c7dfe0c0ad352db2a6d438 AS radarr
FROM lscr.io/linuxserver/sonarr:4.0.19@sha256:4d9df314875e1249ab7d6170c2b9b3dc1d8e6383f168ceb10dc9a5ad9b324739 AS sonarr

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
FROM coredns/coredns:1.14.7@sha256:7efd3c635b03efd68c4e8398fc45f0d993d0e9ab016f72c1cefb0fd6d01aa286 AS coredns
FROM traefik:v3.7.11@sha256:5203c3f39ca70de6790d964624e042463ffbd57715bc82be155cf224c0dd5144 AS traefik

# syncthing
FROM syncthing/syncthing:2.1.3@sha256:8c8ff37ab6aa8be23b700648a90fa9412e214852e9fd6ea8477c8334792daec0 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.2.3@sha256:a00b6a597a3832a1814cde0ef60abc55c94644f3f80902c3432f6af6de8d4a96 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.13.0@sha256:4fb4db4d49a217bed6d0204f454ce809febc565bbe051b85c556ee2bcef73d8c AS zigbee2mqtt
