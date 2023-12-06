# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.4.0 as restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.12.1 as frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2023.11.3 as home-assistant

# media-stack
FROM jellyfin/jellyfin:10.8.13-1 as jellyfin

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.47.2 as cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.0.0 as nut-exporter
FROM prom/blackbox-exporter:v0.24.0 as prometheus-blackbox-exporter
FROM prom/prometheus:v2.48.0 as prometheus
FROM quay.io/prometheus/node-exporter:v1.7.0 as prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:10.2.2 as grafana

# mosquitto
FROM eclipse-mosquitto:2.0.18-openssl as mosquitto

# network-stack
FROM klutchell/unbound:1.19.0 as unbound
FROM traefik:2.10.7 as traefik

# syncthing
FROM syncthing/syncthing:1.26.1 as syncthing

# torrent
FROM linuxserver/qbittorrent:4.6.2 as qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.33.2 as zigbee2mqtt
