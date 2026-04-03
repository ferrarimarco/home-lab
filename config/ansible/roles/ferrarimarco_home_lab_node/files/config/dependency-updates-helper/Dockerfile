# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:2.0.2 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.17.1 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2026.4.1 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.11.7.20260401-001704 AS jellyfin
FROM fallenbagel/jellyseerr:2.7.3 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.4.6 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:3.1.0 AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.3.0 AS prowlarr
FROM lscr.io/linuxserver/radarr:6.1.1 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.19-nightly AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.17 AS sonarr

# monitoring
FROM ghcr.io/google/cadvisor:0.56.2 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.2.5 AS nut-exporter
FROM prom/blackbox-exporter:v0.28.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.11.0 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.10.2 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:12.4.2 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:1.24.2 AS unbound
FROM coredns/coredns:1.14.2 AS coredns
FROM traefik:v3.6.12 AS traefik

# syncthing
FROM syncthing/syncthing:2.0.15 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.1.4 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.9.2 AS zigbee2mqtt
