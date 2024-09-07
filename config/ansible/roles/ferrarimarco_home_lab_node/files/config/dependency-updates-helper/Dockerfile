# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.5.0 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.13.2 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2024.6.4 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.9.10.20240825-063525 AS jellyfin
FROM fallenbagel/jellyseerr:1.9.2 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.21 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.3.3 AS lidarr
FROM lscr.io/linuxserver/prowlarr:1.18.0 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.9.1 AS radarr
FROM lscr.io/linuxserver/readarr:0.3.32-nightly AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.9 AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.50.0@sha256:2f3ea45c7ee3d7a0ce9f9d55a5053bd12285b02aca307ce9657af8e3ea7f6761 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.1 AS nut-exporter
FROM prom/blackbox-exporter:v0.25.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v2.52.0 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.8.2 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:10.4.3 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.18-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:1.20.0 AS unbound
FROM coredns/coredns:1.11.3 AS coredns
FROM traefik:3.0.4 AS traefik

# syncthing
FROM syncthing/syncthing:1.27.12 AS syncthing

# torrent
FROM linuxserver/qbittorrent:4.6.6 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.37.1 AS zigbee2mqtt
