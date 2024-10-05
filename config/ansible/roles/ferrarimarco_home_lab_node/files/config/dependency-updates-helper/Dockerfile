# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:1.6.0@sha256:55cb0e496fc1f6e95f5b68e1d3cf8fa52a91dadb608e4b8093946ffcf2bbe5da AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.14.1@sha256:22e3d0b486df52c3d669682254c2b1bf4205fa6ad8bd8f8c9f7fe76b1517005d AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2024.9.1@sha256:f1a96b632ea6f2b96f882ea17e2ed3660a741d5e45a5278ef0f38abe8e1df6c8 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.9.10.20240825-063525@sha256:79fb3d73a3e995a3960b41d7d1e16ca6a06fb0b9938404ba38c0072a7e5f358c AS jellyfin
FROM fallenbagel/jellyseerr:1.9.2@sha256:8f708df0ce3f202056bde5d7bff625eb59efe38f4ee47bdddc7560b6e4a5a214 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.3.21@sha256:f104ee51e5124d83cf3be9b37480649355d223f7d8f9e453d0d5ef06c6e3b31b AS flaresolverr
FROM lscr.io/linuxserver/lidarr:2.5.3@sha256:c3d8c0970b0e5a7dce0b29930efc83ab33a0fff8d1afbfca88a2104affb80c45 AS lidarr
FROM lscr.io/linuxserver/prowlarr:1.23.1@sha256:8d3da3256868cf40f06cdca2074dee07a190ec42a6df022fb9fe6f73842ba293 AS prowlarr
FROM lscr.io/linuxserver/radarr:5.9.1@sha256:3bee8fb8eb4bb93b77eb4e0c5d755f25649223965af59f5f0363ddda03c6d10c AS radarr
FROM lscr.io/linuxserver/readarr:0.4.0-nightly@sha256:f66fae60533625bb8279c33ccea34b7d66ce6ac5584b1802f343b38ffc88dc19 AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.9@sha256:db80ed8022dd15143644752a57db0553e48e23e3da54bdb9833d28ff89206a3c AS sonarr

# monitoring
FROM gcr.io/cadvisor/cadvisor:v0.50.0@sha256:2f3ea45c7ee3d7a0ce9f9d55a5053bd12285b02aca307ce9657af8e3ea7f6761 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.1.1@sha256:0d9a0a00554081876178369ab9d46717e002fcf550b18dcd85f98c315438b524 AS nut-exporter
FROM prom/blackbox-exporter:v0.25.0@sha256:b04a9fef4fa086a02fc7fcd8dcdbc4b7b35cc30cdee860fdc6a19dd8b208d63e AS prometheus-blackbox-exporter
FROM prom/prometheus:v2.54.1@sha256:f6639335d34a77d9d9db382b92eeb7fc00934be8eae81dbc03b31cfe90411a94 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.8.2@sha256:4032c6d5bfd752342c3e631c2f1de93ba6b86c41db6b167b9a35372c139e7706 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:11.2.0@sha256:408afb9726de5122b00a2576763a8a57a3c86d5b0eff5305bc994ceb3eb96c3f AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.18-openssl@sha256:992792574d67e5fe15264e595d6a808ff0afd324749cd13304416ae012aa4ba7 AS mosquitto

# network-stack
FROM klutchell/unbound:1.21.0@sha256:41a37ebbfc522155cc68c21b783f7b30f041438ae1c3c1ab011cd2e73c1624c5 AS unbound
FROM coredns/coredns:1.11.3@sha256:9caabbf6238b189a65d0d6e6ac138de60d6a1c419e5a341fbbb7c78382559c6e AS coredns
FROM traefik:3.1.2@sha256:3f92eba47bd4bfda91d47b72d16fef2d7ae15db61a92b2057cf0cb389f8938f6 AS traefik

# syncthing
FROM syncthing/syncthing:1.27.12@sha256:5fb5438b300a430f0636b60924939defb84f965b15ad7ae16acf5a2ac9c9e5c3 AS syncthing

# torrent
FROM linuxserver/qbittorrent:4.6.6@sha256:d3b778c7fc388172958ba993ae7acb427f298ea079c3b243313c86a09e0a0991 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:1.40.1@sha256:8127ec2b6e5370eb83033e9cd7250a72bc418b4ead722eadb17c664bebd8b829 AS zigbee2mqtt
