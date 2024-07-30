# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.5.0@sha256:920271a90bfc7396024d76bff780a80b90da7c907937d36ac3d71900df1bf86c as restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.13.2@sha256:2906991ccad85035b176941f9dedfd35088ff710c39d45ef1baa9a49f2b16734 as frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2024.6.4@sha256:17d159928122e6f374bd39b0e75904522bc7d7c2a64e88b248948734e4c4d444 as home-assistant

# media-stack
FROM jellyfin/jellyfin:10.9.8.20240721-051228@sha256:836232f7ffa1fdac5d043a592806422c33c68da2616f303f831e3ac25bfb6f1a as jellyfin
FROM fallenbagel/jellyseerr:1.9.2@sha256:8f708df0ce3f202056bde5d7bff625eb59efe38f4ee47bdddc7560b6e4a5a214 as jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.21@sha256:f104ee51e5124d83cf3be9b37480649355d223f7d8f9e453d0d5ef06c6e3b31b as flaresolverr
FROM lscr.io/linuxserver/lidarr:2.3.3@sha256:32ddd032d57d7e996052b0fe68c651e88f87909eaab26935dc0160ea468a936e as lidarr
FROM lscr.io/linuxserver/prowlarr:1.18.0@sha256:237e9a72c11c5350bf22e355759436ecd4fd660e820d5b556d9a9e436f25f6b9 as prowlarr
FROM lscr.io/linuxserver/radarr:5.6.0@sha256:79053c07400eec909d04ac97db760c30bf61471ec37465a50f126a3c825a92bc as radarr
FROM lscr.io/linuxserver/readarr:0.3.32-nightly@sha256:9885cf0129d5b790db15db2b97a0e7bd9352fce0e3af8395d5f0ff3bb3a32558 as readarr
FROM lscr.io/linuxserver/sonarr:4.0.8@sha256:fbee5770f688e4f89dd073534feda11251bfde0e0a4e6ac74dd8c33bb856b505 as sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.49.1@sha256:3cde6faf0791ebf7b41d6f8ae7145466fed712ea6f252c935294d2608b1af388 as cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.1@sha256:0d9a0a00554081876178369ab9d46717e002fcf550b18dcd85f98c315438b524 as nut-exporter
FROM prom/blackbox-exporter:v0.25.0@sha256:b04a9fef4fa086a02fc7fcd8dcdbc4b7b35cc30cdee860fdc6a19dd8b208d63e as prometheus-blackbox-exporter
FROM prom/prometheus:v2.52.0@sha256:5c435642ca4d8427ca26f4901c11114023004709037880cd7860d5b7176aa731 as prometheus
FROM quay.io/prometheus/node-exporter:v1.8.2@sha256:4032c6d5bfd752342c3e631c2f1de93ba6b86c41db6b167b9a35372c139e7706 as prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:10.4.3@sha256:b7fcb534f7b3512801bb3f4e658238846435804deb479d105b5cdc680847c272 as grafana

# mosquitto
FROM eclipse-mosquitto:2.0.18-openssl@sha256:2f1c61fc5af49d0b589978e146dcfc60248d93d88292ff9373c4e6d083a63c72 as mosquitto

# network-stack
FROM klutchell/unbound:1.20.0@sha256:7f8bd396b3b82e0502803f0b1c2e7a635ec8bccd973763a5a95a3c9d2b72e07d as unbound
FROM coredns/coredns:1.11.3@sha256:9caabbf6238b189a65d0d6e6ac138de60d6a1c419e5a341fbbb7c78382559c6e as coredns
FROM traefik:3.0.4@sha256:a208c74fd80a566d4ea376053bff73d31616d7af3f1465a7747b8b89ee34d97e as traefik

# syncthing
FROM syncthing/syncthing:1.27.9@sha256:9f16c4aaf678add90a85bd53e324bfbb57d1e704e6a07b54c446e4a67e590dbf as syncthing

# torrent
FROM linuxserver/qbittorrent:4.6.5@sha256:a99a5a580624a1a09117e84342544eccfccb7b1373efdf6b76b1b974076ccfae as qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.37.1@sha256:d37f2f8227d9c2763ddbe06e48328f9ec3a9b8cf081dfcbda44c9b0af4c0c634 as zigbee2mqtt
