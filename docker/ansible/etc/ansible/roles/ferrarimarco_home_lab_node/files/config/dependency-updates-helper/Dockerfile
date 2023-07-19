# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.2.2 as restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.12.1 as frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2023.7.2 as home-assistant

# media-stack
FROM jellyfin/jellyfin:10.8.10 as jellyfin

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.47.2 as cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.0.0 as nut-exporter
FROM prom/blackbox-exporter:v0.24.0 as prometheus-blackbox-exporter
FROM prom/prometheus:v2.45.0 as prometheus
FROM quay.io/prometheus/node-exporter:v1.6.1 as prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:9.5.5 as grafana

# mosquitto
FROM eclipse-mosquitto:2.0.15-openssl as mosquitto

# network-stack
FROM klutchell/unbound:v1.17.1 as unbound
FROM traefik:2.10.3 as traefik

# syncthing
FROM syncthing/syncthing:1.23.6 as syncthing

# torrent
FROM linuxserver/qbittorrent:4.5.4 as qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.32.1 as zigbee2mqtt
