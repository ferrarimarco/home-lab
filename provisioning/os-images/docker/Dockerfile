FROM ubuntu:20.04

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    TERM=linux \
    TZ=Etc/UTC \
    apt-get \
    --no-install-recommends --yes install \
    cloud-image-utils \
    cloud-init \
    curl \
    kpartx \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV WORKDIR /tmp/workdir
WORKDIR ${WORKDIR}

COPY scripts/entrypoint.sh /entrypoint.sh

RUN chmod a+x /*.sh
ENTRYPOINT ["/entrypoint.sh"]
