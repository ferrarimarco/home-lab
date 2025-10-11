# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.7.0@sha256:1867eb1ef7e6ecb812a03520a7cdf09ea706706de9c112ced0a88b53f5768103 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.16.1@sha256:cb6624b9075f76ece626139eedca7e728cab1456a5f8c351afbf877320826bc1 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2025.10.0@sha256:ae0e2a2f03822c49a0c506bc40e367b4abc8b3207d67a6e0312b42d60867c5e5 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.10.7.20250405-191553@sha256:7ae36aab93ef9b6aaff02b37f8bb23df84bb2d7a3f6054ec8fc466072a648ce2 AS jellyfin
FROM fallenbagel/jellyseerr:2.7.3@sha256:4538137bc5af902dece165f2bf73776d9cf4eafb6dd714670724af8f3eb77764 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.4.1@sha256:5379a9209c86870558d77c8cdf7efdf300aecf0447617a05dc77e0491d53f34c AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.13.3@sha256:e9ab17c7d4738a735a50b6e8f129d09a4166081f33b140d5d93177b2b12b069d AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.0.5@sha256:964485823771c102427a0c1cd896cf6b576add6f21bd041498b92cb040ee7270 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.27.5@sha256:f174546a0ad7eb9a9170e4142bef6f74ef3ebfe6209528fded40630369406dc0 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.19-nightly@sha256:4f291128d1a5538be73c2a30473d7cdd0820e223dc8b8533b0cbc5659000dcbe AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.15@sha256:f3a7fda30a0133b24b04857a21e7a81b97ed2722e147503a47ad0b4fbc7c7694 AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.52.1@sha256:f40e65878e25c2e78ea037f73a449527a0fb994e303dc3e34cb6b187b4b91435 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.2.1@sha256:3b452a9f29c50cad2909a9815ff8cf13b1f1079a641492bf7d06063725846e28 AS nut-exporter
FROM prom/blackbox-exporter:v0.27.0@sha256:a50c4c0eda297baa1678cd4dc4712a67fdea713b832d43ce7fcc5f9bea05094d AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.6.0@sha256:76947e7ef22f8a698fc638f706685909be425dbe09bd7a2cd7aca849f79b5f64 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.9.1@sha256:d00a542e409ee618a4edc67da14dd48c5da66726bbd5537ab2af9c1dfc442c8a AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:12.1.1@sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl@sha256:fd9982f5ed92a6c2a90805601d2275f8fbd7f2d47c4cb3836f7db0bdc7a91bec AS mosquitto

# network-stack
FROM klutchell/unbound:1.24.0@sha256:62816542e5dcecad24701a15aa5b31746b0319c12073b2ce9e5010a2cfcfd163 AS unbound
FROM coredns/coredns:1.12.4@sha256:986f04c2e15e147d00bdd51e8c51bcef3644b13ff806be7d2ff1b261d6dfbae1 AS coredns
FROM traefik:3.5.3@sha256:d6be8725d21b45bdd84b93ea01438256e0e3c94aa8fa51834fe87f37cd5d4af8 AS traefik

# syncthing
FROM syncthing/syncthing:2.0.10@sha256:3faeb52baa7de3fbe7007cecc6829a4bc71cc6ac62d3967459a8228979c38943 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.1.2@sha256:032801369ba08f6a40e852f5334671c413c38036847927e1cf14b66784f74adb AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.6.2@sha256:ffabf256f4550175278fbeebdbc3f174f2ffa005175e755324c5f06020af3e68 AS zigbee2mqtt
