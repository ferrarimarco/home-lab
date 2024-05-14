# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.5.0 as restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.13.2 as frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2024.5.3 as home-assistant

# media-stack
FROM jellyfin/jellyfin:10.9.1.20240513-003058 as jellyfin
FROM fallenbagel/jellyseerr:1.8.1 as jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.17 as flaresolverr
FROM lscr.io/linuxserver/prowlarr:1.16.2 as prowlarr
FROM lscr.io/linuxserver/radarr:5.4.6 as radarr
FROM lscr.io/linuxserver/sonarr:4.0.4 as sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.49.1 as cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.1 as nut-exporter
FROM prom/blackbox-exporter:v0.25.0 as prometheus-blackbox-exporter
FROM prom/prometheus:v2.52.0 as prometheus
FROM quay.io/prometheus/node-exporter:v1.8.0 as prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:10.4.3 as grafana

# mosquitto
FROM eclipse-mosquitto:2.0.18-openssl as mosquitto

# network-stack
FROM klutchell/unbound:1.20.0 as unbound
FROM traefik:3.0.0 as traefik

# syncthing
FROM syncthing/syncthing:1.27.7 as syncthing

# torrent
FROM linuxserver/qbittorrent:4.6.4 as qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.37.1 as zigbee2mqtt
