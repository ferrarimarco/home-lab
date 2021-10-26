FROM ubuntu:20.04

RUN apt-get update \
    && apt-get \
    --no-install-recommends \
    --yes \
    install \
    cloud-image-utils \
    cloud-init \
    kpartx \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV WORKDIR /tmp/workdir
WORKDIR ${WORKDIR}

COPY scripts/entrypoint.sh /entrypoint.sh

RUN chmod a+x /*.sh
ENTRYPOINT ["/entrypoint.sh"]
