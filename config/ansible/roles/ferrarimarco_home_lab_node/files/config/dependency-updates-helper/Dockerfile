# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.7.0@sha256:1867eb1ef7e6ecb812a03520a7cdf09ea706706de9c112ced0a88b53f5768103 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.16.0@sha256:c2d49a6fedcca8928db1eccfa8018c8138b25dfe7d506a7ea499aebc3c799b0b AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2025.8.2@sha256:cd742b4b3311c7e84a978448860088e734221e9314b73e3931d148d1b081a263 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.10.7.20250405-191553@sha256:7ae36aab93ef9b6aaff02b37f8bb23df84bb2d7a3f6054ec8fc466072a648ce2 AS jellyfin
FROM fallenbagel/jellyseerr:2.7.3@sha256:4538137bc5af902dece165f2bf73776d9cf4eafb6dd714670724af8f3eb77764 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.25@sha256:68160ec125e5cde23bc45549a443da0da0223cf4f0de7571ed2c6851cf6e1561 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.12.4@sha256:9f14ac890945e8964e2d2fa3eff6dc8d52fdfdb70502bdf8d6cdd369bd1aaca1 AS lidarr
FROM lscr.io/linuxserver/prowlarr:1.37.0@sha256:25d21c04c7cc39a706217abb77bb60b283d9eaaf16acf539c930e3c797e21f25 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.26.2@sha256:7eb64f5af8bbe48e79bc55c0c37ca8db89b2f073a9ff0094f603916ae1df9de8 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.19-nightly@sha256:4f291128d1a5538be73c2a30473d7cdd0820e223dc8b8533b0cbc5659000dcbe AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.15@sha256:e00e87e0e7c24fdc992093756f120a6ab292790b6a637ff3641bf813091cd726 AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.52.1@sha256:f40e65878e25c2e78ea037f73a449527a0fb994e303dc3e34cb6b187b4b91435 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.2.1@sha256:3b452a9f29c50cad2909a9815ff8cf13b1f1079a641492bf7d06063725846e28 AS nut-exporter
FROM prom/blackbox-exporter:v0.27.0@sha256:a50c4c0eda297baa1678cd4dc4712a67fdea713b832d43ce7fcc5f9bea05094d AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.5.0@sha256:63805ebb8d2b3920190daf1cb14a60871b16fd38bed42b857a3182bc621f4996 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.9.1@sha256:d00a542e409ee618a4edc67da14dd48c5da66726bbd5537ab2af9c1dfc442c8a AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:12.1.1@sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl@sha256:d219d3a72847f3aed6a1d66975972d3b17f86e39e8f6f6b86b4088b879c1a2d6 AS mosquitto

# network-stack
FROM klutchell/unbound:1.23.1@sha256:a3412dcc5cf5e98dfde226bca68154a80027aaca5c4ffd864fc89140a446ff57 AS unbound
FROM coredns/coredns:1.12.3@sha256:1391544c978029fcddc65068f6ad67f396e55585b664ecccd7fefba029b9b706 AS coredns
FROM traefik:3.5.0@sha256:4e7175cfe19be83c6b928cae49dde2f2788fb307189a4dc9550b67acf30c11a5 AS traefik

# syncthing
FROM syncthing/syncthing:2.0.2@sha256:0c62d8223eb8cdf2451452aa567ef628dfcb2b53af2bd25b56517617ae898c35 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.1.2@sha256:d464a92d5656f1fa66baafe610a06a6cafd4bdf900a245e6f20b220f281b456d AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.6.0@sha256:472f4f5ed5d4258056093ea5745bc0ada37628b667d7db4fb12c2ffea74b2703 AS zigbee2mqtt
