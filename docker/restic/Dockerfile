FROM debian:bullseye

RUN apt-get update \
    && apt-get --assume-yes --no-install-recommends install \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get --assume-yes --no-install-recommends install \
    restic \
    && rm -rf /var/lib/apt/lists/* \
    && restic self-update \
    && restic --version
