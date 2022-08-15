FROM debian:bookworm

RUN apt-get update \
    && apt-get --assume-yes --no-install-recommends install \
    qbittorrent-nox \
    && rm -rf /var/lib/apt/lists/*
