# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.5.0@sha256:920271a90bfc7396024d76bff780a80b90da7c907937d36ac3d71900df1bf86c as restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.13.2@sha256:2906991ccad85035b176941f9dedfd35088ff710c39d45ef1baa9a49f2b16734 as frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2024.5.5@sha256:031d355a2e52e82fc33cd6854753fb19fc5d6a31af6f0f54c277d6f118ad993e as home-assistant

# media-stack
FROM jellyfin/jellyfin:10.9.7.20240625-002012@sha256:76930362d2c266e8f0b2f51f1c6b039a5207525d0e138a1cdbec870c66c34b0f as jellyfin
FROM fallenbagel/jellyseerr:1.9.2@sha256:8f708df0ce3f202056bde5d7bff625eb59efe38f4ee47bdddc7560b6e4a5a214 as jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.21@sha256:f104ee51e5124d83cf3be9b37480649355d223f7d8f9e453d0d5ef06c6e3b31b as flaresolverr
FROM lscr.io/linuxserver/lidarr:2.3.3@sha256:11150c79f17ce8ad3d76aea1191714451ab73df7dbcac587d30dd729a7266eb8 as lidarr
FROM lscr.io/linuxserver/prowlarr:1.18.0@sha256:237e9a72c11c5350bf22e355759436ecd4fd660e820d5b556d9a9e436f25f6b9 as prowlarr
FROM lscr.io/linuxserver/radarr:5.6.0@sha256:79053c07400eec909d04ac97db760c30bf61471ec37465a50f126a3c825a92bc as radarr
FROM lscr.io/linuxserver/readarr:0.3.30-nightly@sha256:235a2d9d53e068d2cf405a4b2179de748aab94c34ce26ce7f00cf461946d42fd as readarr
FROM lscr.io/linuxserver/sonarr:4.0.5@sha256:275467ba17d990bbc6301dec3cc76b042969836749de39067818759d0f3b407f as sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.49.1@sha256:3cde6faf0791ebf7b41d6f8ae7145466fed712ea6f252c935294d2608b1af388 as cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.1@sha256:0d9a0a00554081876178369ab9d46717e002fcf550b18dcd85f98c315438b524 as nut-exporter
FROM prom/blackbox-exporter:v0.25.0@sha256:b04a9fef4fa086a02fc7fcd8dcdbc4b7b35cc30cdee860fdc6a19dd8b208d63e as prometheus-blackbox-exporter
FROM prom/prometheus:v2.52.0@sha256:5c435642ca4d8427ca26f4901c11114023004709037880cd7860d5b7176aa731 as prometheus
FROM quay.io/prometheus/node-exporter:v1.8.0@sha256:8a57af80a4c77ffb97749b44895248563616fcfd405b5370d5db35fe6c15e4ec as prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:10.4.3@sha256:b7fcb534f7b3512801bb3f4e658238846435804deb479d105b5cdc680847c272 as grafana

# mosquitto
FROM eclipse-mosquitto:2.0.18-openssl@sha256:9f14048836b77f5fe1e03487b8bdef47b58caf21db2f15741fce4b23596652b1 as mosquitto

# network-stack
FROM klutchell/unbound:1.20.0@sha256:7f8bd396b3b82e0502803f0b1c2e7a635ec8bccd973763a5a95a3c9d2b72e07d as unbound
FROM traefik:3.0.3@sha256:a00ced69e41bf2eb475fd0cc70c1be785e4a5f45d693f26360b688c48816717f as traefik

# syncthing
FROM syncthing/syncthing:1.27.8@sha256:c1fdac67e9a5dd4fa0388b240bbaf387dddb2909466923a721d66463b76fba39 as syncthing

# torrent
FROM linuxserver/qbittorrent:4.6.5@sha256:6373e7aa04e428990cc760525a50a510cbe5348453c5485f84068c9a0198a485 as qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.37.1@sha256:d37f2f8227d9c2763ddbe06e48328f9ec3a9b8cf081dfcbda44c9b0af4c0c634 as zigbee2mqtt
