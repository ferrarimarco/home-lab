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
FROM lscr.io/linuxserver/lidarr:3.1.0@sha256:8ab0fd370b604ae034d9a9c261a9d8d873bece33d9736852e7ce4f3566e4a35d AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.5.2@sha256:aaa16ba7d66e413db6d0358d3b6c68d833578ba7f176f24a51807181e7637fce AS prowlarr
FROM lscr.io/linuxserver/radarr:6.3.0@sha256:fe051413dfd91b383ba04910552e83fb0306895fefee275c48dafe7bb90807dc AS radarr
FROM lscr.io/linuxserver/sonarr:4.0.19@sha256:82172b363f9eddc02aca544f880a044f2ceb9aaf190bc87e4454e2f705eb91d0 AS sonarr

# monitoring
FROM ghcr.io/google/cadvisor:v0.60.5@sha256:763aecf1c32c2be8a1a75f9abfc2fc461005c9dbbaa39cb356b354aac1296dbe AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.3.0@sha256:276460d141c732772f8b1fcd785a7de272473e6d39fd85c32b163efc2999cb9a AS nut-exporter
FROM prom/blackbox-exporter:v0.28.0@sha256:e753ff9f3fc458d02cca5eddab5a77e1c175eee484a8925ac7d524f04366c2fc AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.14.0@sha256:5ce7540c3c00ef4ab0c9d2c995c6a5b9c421f44b4a115d97a2c7af3b1c21cbb0 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.12.1@sha256:1b4e4438faca4dd7e001dd445d161a4a2091b0fededa84093b3a8dfeae1f1be0 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:13.0.2@sha256:5dad0df181cb644a14e13617b913b261a54f7d4fd4510721dba420929f35bea2 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl@sha256:199ea8ef2e35ec2b1b37e59cfd1dbae538ed4dfa4a2251a121a52215a6248a21 AS mosquitto

# network-stack
FROM klutchell/unbound:v1.26.0@sha256:5020cfe1218aeda38777f88279220162e602c3a44efc684550dbf46137106a16 AS unbound
FROM coredns/coredns:1.14.7@sha256:7efd3c635b03efd68c4e8398fc45f0d993d0e9ab016f72c1cefb0fd6d01aa286 AS coredns
FROM traefik:v3.7.11@sha256:5203c3f39ca70de6790d964624e042463ffbd57715bc82be155cf224c0dd5144 AS traefik

# syncthing
FROM syncthing/syncthing:2.1.3@sha256:8c8ff37ab6aa8be23b700648a90fa9412e214852e9fd6ea8477c8334792daec0 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.2.3@sha256:2be038f3421f60f62e8e4bf201f66f385b68e4fbc9ed3ab79051069ea22e2650 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.13.0@sha256:4fb4db4d49a217bed6d0204f454ce809febc565bbe051b85c556ee2bcef73d8c AS zigbee2mqtt
