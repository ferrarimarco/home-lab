# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.6.0 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.14.1 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2025.1.2 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.10.3.20241119-033930 AS jellyfin
FROM fallenbagel/jellyseerr:2.2.3 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.21 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.8.2 AS lidarr
FROM lscr.io/linuxserver/prowlarr:1.29.2 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.17.2 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.9-nightly AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.12 AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.51.0 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.3 AS nut-exporter
FROM prom/blackbox-exporter:v0.25.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.1.0 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.8.2 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:11.4.0 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.20-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:1.22.0 AS unbound
FROM coredns/coredns:1.12.0 AS coredns
FROM traefik:3.3.0 AS traefik

# syncthing
FROM syncthing/syncthing:1.29.2 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.0.3 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.0.0 AS zigbee2mqtt
