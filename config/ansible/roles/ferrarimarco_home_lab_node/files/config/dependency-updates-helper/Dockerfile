# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:2.0.0 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.16.3 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2025.12.2 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.11.4.20251201-025340 AS jellyfin
FROM fallenbagel/jellyseerr:2.7.3 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.4.6 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:3.1.0 AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.3.0 AS prowlarr
FROM lscr.io/linuxserver/radarr:6.0.4 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.19-nightly AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.16 AS sonarr

# monitoring
FROM ghcr.io/google/cadvisor:v0.53.0 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.2.2 AS nut-exporter
FROM prom/blackbox-exporter:v0.28.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.8.0 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.10.2 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:12.1.1 AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:1.24.2 AS unbound
FROM coredns/coredns:1.13.2 AS coredns
FROM traefik:3.6.4 AS traefik

# syncthing
FROM syncthing/syncthing:2.0.12 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.1.4 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.7.1 AS zigbee2mqtt
