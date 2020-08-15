FROM multiarch/qemu-user-static:register AS register

FROM ubuntu:focal

RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install -qqy --no-install-recommends \
    build-essential \
    ca-certificates \
    dosfstools \
    gdisk \
    kpartx \
    libarchive-tools \
    parted \
    psmisc \
    qemu-user-static \
    qemu-utils \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY --from=register /register /register
COPY --from=register /qemu-binfmt-conf.sh /qemu-binfmt-conf.sh

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
