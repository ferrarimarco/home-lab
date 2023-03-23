FROM multiarch/qemu-user-static:register AS register

FROM ubuntu:23.04

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && apt-get update \
  && DEBIAN_FRONTEND=noninteractive \
  TERM=linux \
  TZ=Etc/UTC \
  apt-get \
  --no-install-recommends --yes install \
  binfmt-support \
  build-essential \
  cloud-image-utils \
  cloud-init \
  curl \
  lsof \
  qemu \
  qemu-user-static \
  qemu-utils \
  rsync \
  unzip \
  xz-utils \
  && rm -rf /var/lib/apt/lists/*

COPY --from=register /register /register
COPY --from=register /qemu-binfmt-conf.sh /qemu-binfmt-conf.sh

ENV WORKDIR /tmp/workdir
WORKDIR ${WORKDIR}

COPY scripts/*.sh /

RUN chmod a+x /*.sh
ENTRYPOINT ["/entrypoint.sh"]
