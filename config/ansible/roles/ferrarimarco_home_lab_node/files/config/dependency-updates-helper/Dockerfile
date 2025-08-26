# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.7.0 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.16.0 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2025.8.3 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.10.7.20250405-191553 AS jellyfin
FROM fallenbagel/jellyseerr:2.7.3 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.4.0 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.12.4 AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.0.5 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.26.2 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.19-nightly AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.15 AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.52.1 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.2.1 AS nut-exporter
FROM prom/blackbox-exporter:v0.27.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.5.0 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.9.1 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:12.1.1 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:1.23.1 AS unbound
FROM coredns/coredns:1.12.3 AS coredns
FROM traefik:3.5.0 AS traefik

# syncthing
FROM syncthing/syncthing:2.0.3 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.1.2 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.6.0 AS zigbee2mqtt
