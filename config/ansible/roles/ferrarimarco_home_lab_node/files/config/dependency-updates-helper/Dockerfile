# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.6.0 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.14.1 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2025.2.5 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.10.6.20250216-215628 AS jellyfin
FROM fallenbagel/jellyseerr:2.3.0 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.21 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.9.6 AS lidarr
FROM lscr.io/linuxserver/prowlarr:1.31.2 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.19.3 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.12-nightly AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.13 AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.51.0 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.3 AS nut-exporter
FROM prom/blackbox-exporter:v0.25.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.2.1 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.8.2 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:11.5.2 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.20-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:1.22.0 AS unbound
FROM coredns/coredns:1.12.0 AS coredns
FROM traefik:3.3.4 AS traefik

# syncthing
FROM syncthing/syncthing:1.29.2 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.0.4 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.1.3 AS zigbee2mqtt
