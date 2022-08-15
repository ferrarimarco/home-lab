FROM debian:bookworm

RUN apt-get update \
    && apt-get --assume-yes --no-install-recommends install \
    qbittorrent-nox \
    && rm -rf /var/lib/apt/lists/*

# 8080 is the default qbittorrent WebUI port
EXPOSE 8080 6881 6881/udp

COPY root/ /

ENTRYPOINT [ "qbittorrent-nox", "-d" ]
