# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.6.0 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.14.1 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2024.11.1 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.10.1.20241103-155831 AS jellyfin
FROM fallenbagel/jellyseerr:2.0.1 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.21 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.7.1 AS lidarr
FROM lscr.io/linuxserver/prowlarr:1.25.4 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.14.0 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.4-nightly AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.10 AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.51.0 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.1 AS nut-exporter
FROM prom/blackbox-exporter:v0.25.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v2.55.1 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.9.1 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:11.3.0 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.20-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:1.22.0 AS unbound
FROM coredns/coredns:1.11.4 AS coredns
FROM traefik:3.2.0 AS traefik

# syncthing
FROM syncthing/syncthing:1.28.0 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.0.1 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.41.0 AS zigbee2mqtt
