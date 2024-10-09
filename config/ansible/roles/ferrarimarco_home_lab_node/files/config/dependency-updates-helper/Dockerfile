# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.6.0 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.14.1 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2024.9.1 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.9.10.20240825-063525 AS jellyfin
FROM fallenbagel/jellyseerr:1.9.2 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.21 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.5.3 AS lidarr
FROM lscr.io/linuxserver/prowlarr:1.23.1 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.9.1 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.0-nightly AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.9 AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.50.0 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.1 AS nut-exporter
FROM prom/blackbox-exporter:v0.25.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v2.54.1 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.8.2 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:11.2.0 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.18-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:1.21.0 AS unbound
FROM coredns/coredns:1.11.3 AS coredns
FROM traefik:3.1.6 AS traefik

# syncthing
FROM syncthing/syncthing:1.27.12 AS syncthing

# torrent
FROM linuxserver/qbittorrent:4.6.6 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.40.1 AS zigbee2mqtt
