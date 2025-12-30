# The purpose of this file is to group container image identifiers so that automated
# dependency management can manage updates.
# We then fetch these identifiers for use in templates.

# backup
FROM ngosang/restic-exporter:2.0.0@sha256:d39e27b97a75b5ff16067309e4f566005ab3ccb7a40bf76f7dc6d423da18e61d AS restic-exporter

# frigate
FROM ghcr.io/blakeblackshear/frigate:0.16.3@sha256:cf4305d9f1c673d71c4d0fab30ca56ca05ac91168711a74ee7867a4691a7ad02 AS frigate

# home-assistant
FROM ghcr.io/home-assistant/home-assistant:2025.12.3@sha256:c9da2a0a5738ceb26e1b4f672825c09371e51ae5e285beffa3072757b7817f3e AS home-assistant

# media-stack
FROM jellyfin/jellyfin:10.11.4.20251201-025340@sha256:aab0b50a3ce43a41621fc7040a379cc57174059aec8f9c17a90176649a0c1ab1 AS jellyfin
FROM fallenbagel/jellyseerr:2.7.3@sha256:4538137bc5af902dece165f2bf73776d9cf4eafb6dd714670724af8f3eb77764 AS jellyseerr
FROM ghcr.io/flaresolverr/flaresolverr:v3.4.6@sha256:7962759d99d7e125e108e0f5e7f3cdbcd36161776d058d1d9b7153b92ef1af9e AS flaresolverr
FROM lscr.io/linuxserver/lidarr:3.1.0@sha256:ede2bb17350cc97a0d3f24389aa91803f655eac29aa022c77a71f4a61cc621e4 AS lidarr
FROM lscr.io/linuxserver/prowlarr:2.3.0@sha256:67a8aaedcfd6989f3030b937a6a07007310b1dfc7ee8df16d2cbfa48d1c1158c AS prowlarr
FROM lscr.io/linuxserver/radarr:6.0.4@sha256:6c0948b42c149e36bb3dbc0b64d36c77b2d3c9dccf1b424c4f72af1e57ba0c21 AS radarr
FROM lscr.io/linuxserver/readarr:0.4.19-nightly@sha256:4f291128d1a5538be73c2a30473d7cdd0820e223dc8b8533b0cbc5659000dcbe AS readarr
FROM lscr.io/linuxserver/sonarr:4.0.16@sha256:8b9f2138ec50fc9e521960868f79d2ad0d529bc610aef19031ea8ff80b54c5e0 AS sonarr

# monitoring
FROM ghcr.io/google/cadvisor:0.54.1@sha256:80e55785e1fa6bcf2b2f372eec4859608f1fe9646bb087f05c7916118b541552 AS cadvisor
FROM ghcr.io/druggeri/nut_exporter:3.2.2@sha256:a203474e5b24eddf33b45013d9dd72c41769abeaad6a8cbf6316610a96dc5a95 AS nut-exporter
FROM prom/blackbox-exporter:v0.28.0@sha256:e753ff9f3fc458d02cca5eddab5a77e1c175eee484a8925ac7d524f04366c2fc AS prometheus-blackbox-exporter
FROM prom/prometheus:v3.8.0@sha256:d936808bdea528155c0154a922cd42fd75716b8bb7ba302641350f9f3eaeba09 AS prometheus
FROM quay.io/prometheus/node-exporter:v1.10.2@sha256:337ff1d356b68d39cef853e8c6345de11ce7556bb34cda8bd205bcf2ed30b565 AS prometheus-node-exporter

# monitoring-backend
FROM grafana/grafana-oss:12.1.1@sha256:a1701c2180249361737a99a01bc770db39381640e4d631825d38ff4535efa47d AS grafana

# mosquitto
FROM eclipse-mosquitto:2.0.22-openssl@sha256:077fe4ff4c49df1e860c98335c77dda08360629e0e2a718147027e4db3eace9d AS mosquitto

# network-stack
FROM klutchell/unbound:1.24.2@sha256:cb9a0f06c803c764395e2ff50bd8a244470601290c78fb2cdcf1bd200a027cd6 AS unbound
FROM coredns/coredns:1.13.2@sha256:94caebb89dcfb9d2c4be45bfda34410a3e1092458fbbbc0284365c9e4c9a7818 AS coredns
FROM traefik:3.6.4@sha256:c5bd185c41ba3dbb42cf8a1b9fbdc368bdc96f90c8e598134879935f64e7a7f1 AS traefik

# syncthing
FROM syncthing/syncthing:2.0.12@sha256:7ae77d066e9b81d3d8c312b2f9e1a874a5115680bfde90aff5fc9aece694ec93 AS syncthing

# torrent
FROM linuxserver/qbittorrent:5.1.4@sha256:1497b6e047ad47b738f94739219f0e5c5b2ad7a5953b7cf0050f2fedddd8c601 AS qbittorrent

# zigbee2mqtt
FROM koenkk/zigbee2mqtt:2.7.1@sha256:163e7351430a95d550d5b1bb958527edc1eff115eb013ca627f3545a192e853f AS zigbee2mqtt
