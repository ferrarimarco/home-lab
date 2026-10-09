# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:2.1.2 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.18.0 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2026.9.4 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:12.1.20260915-010956 AS jellyfin
FROM ghcr.io/seerr-team/seerr:v3.5.0 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.5.2 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:3.1.0 AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.6.5 AS prowlarr
FROM lscr.io/linuxserver/radarr:6.4.4 AS radarr
FROM lscr.io/linuxserver/sonarr:4.0.20 AS sonarr

# monitoring
FROM ghcr.io/google/cadvisor:v0.60.6 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.3.0 AS nut-exporter
FROM prom/blackbox-exporter:v0.28.0 AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.15.0 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.12.1 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:13.0.2 AS grafana
FROM prom/alertmanager:v0.34.1 AS alertmanager

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl AS mosquitto

# network-stack
FROM klutchell/unbound:v1.26.1 AS unbound
FROM coredns/coredns:1.14.7 AS coredns
FROM traefik:v3.7.13 AS traefik

# syncthing
FROM syncthing/syncthing:2.1.5 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.2.4 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.14.2 AS zigbee2mqtt
