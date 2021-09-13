FROM ubuntu:20.04

RUN apt-get update \
    && apt-get \
    --no-install-recommends \
    --yes \
    install \
    cloud-image-utils=0.31-7-gd99b2d76-0ubuntu1 \
    cloud-init=21.2-3-g899bfaa9-0ubuntu2~20.04.1 \
    kpartx=0.8.3-1ubuntu2 \
    wget=1.20.3-1ubuntu1 \
    xz-utils=5.2.4-1ubuntu1 \
    && rm -rf /var/lib/apt/lists/*

ENV WORKDIR /tmp/workdir
WORKDIR ${WORKDIR}

COPY scripts/customize-preinstalled-os-image.sh /customize-preinstalled-os-image.sh
COPY scripts/generate-cloud-init-cidata-iso.sh /generate-cloud-init-cidata-iso.sh

RUN chmod a+x /*.sh
ENTRYPOINT ["/customize-preinstalled-os-image.sh"]
