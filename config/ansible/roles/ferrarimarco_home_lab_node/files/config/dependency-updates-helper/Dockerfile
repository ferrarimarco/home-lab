# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:2.1.2@sha256:a8f9cfa3016237c7008aefa4d9c6639bc9b34d2582eed07ac58dcf56632e4170 AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.18.0@sha256:9678a83a76e4730ac7d9ea7428370e32ae656d6b312aaad30d6c69f3fef14d35 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2026.9.4@sha256:3e6710a7ab2a61311d9d899b719f6c3657791c63e8f4942cec4ebc42401d6b76 AS home-assistant

# media-stack
FROM jellyfin/jellyfin:12.1.20260915-010956@sha256:78d3ea1207d1322471fcac39a614f004f2ccf7e878f95ab2977d752f07e4dd7e AS jellyfin
FROM ghcr.io/seerr-team/seerr:v3.5.0@sha256:27602401178d54f1964442287b9f23f67a3fa2252645ee8065839ea1c3f69e45 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.5.2@sha256:c80ae007ce2ccdcd217a12426e4f039ef763ff90738c808d38810c3e59323767 AS flaresolverr
FROM lscr.io/linuxserver/lidarr:3.1.0@sha256:67887807b13ae025c0fe979da298347c8609969087ab064c81d8e9acc1e06bbf AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.6.5@sha256:f9151e5bc1025c6d0a630d503210cdcb6bb55a7cc098562609d96a408d838902 AS prowlarr
FROM lscr.io/linuxserver/radarr:6.4.4@sha256:7dfd049e79c00b16fbc29c3f5d96a9e7b9e73a23930b4c5b3c4541d60b366814 AS radarr
FROM lscr.io/linuxserver/sonarr:4.0.20@sha256:dffc730adcb8b4f4342792fbb27fcad9c62fb8660523f2aeb082416980d7fe0c AS sonarr

# monitoring
FROM ghcr.io/google/cadvisor:v0.60.6@sha256:b8e7d1093144fd088f425ff003d75a4aa405de075db78dae3bc563730b1bd07a AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.3.0@sha256:276460d141c732772f8b1fcd785a7de272473e6d39fd85c32b163efc2999cb9a AS nut-exporter
FROM prom/blackbox-exporter:v0.28.0@sha256:e753ff9f3fc458d02cca5eddab5a77e1c175eee484a8925ac7d524f04366c2fc AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.15.0@sha256:efd719c99d83b060d9daefdcf00360461adf279f45ef5391f8d111892118753e AS prometheus
FROM quay.io/prometheus/node-exporter:v1.12.1@sha256:1b4e4438faca4dd7e001dd445d161a4a2091b0fededa84093b3a8dfeae1f1be0 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:13.0.2@sha256:5dad0df181cb644a14e13617b913b261a54f7d4fd4510721dba420929f35bea2 AS grafana
FROM prom/alertmanager:v0.34.1@sha256:e9733bafb1bdef9b00e25a21f8f99dc26a22224bf16641ad754d1649f4c3357a AS alertmanager

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl@sha256:199ea8ef2e35ec2b1b37e59cfd1dbae538ed4dfa4a2251a121a52215a6248a21 AS mosquitto

# network-stack
FROM klutchell/unbound:v1.26.1@sha256:9a3939ca33d6d3b42b81a70391bb8e43f0a08d2bd7a3fdffb43d427493345c36 AS unbound
FROM coredns/coredns:1.14.7@sha256:7efd3c635b03efd68c4e8398fc45f0d993d0e9ab016f72c1cefb0fd6d01aa286 AS coredns
FROM traefik:v3.7.13@sha256:24841fe2de7304c149343d877d2923b4c8800a38ba015dea9174c23b20e344a0 AS traefik

# syncthing
FROM syncthing/syncthing:2.1.5@sha256:397aa00b92b48d65540ea3ae3cbf271b87bdccbe07a0b7bd7d2debc3a7b29138 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.2.4@sha256:b522f9f4b769f8f36d49d22d5eb6a92e9aa18904c6a1830b1439df511ec21983 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.14.2@sha256:addbfb08fcef2e4477de1535636118241e10d13e898fbe4d9faba8a4d7396311 AS zigbee2mqtt
