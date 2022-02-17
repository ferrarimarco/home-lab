FROM multiarch/qemu-user-static:register AS register

FROM ubuntu:20.04

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

ENV CROSS_COMPILE_ARCHS "arm64"

# Allow us to install packages for cross-compiling architectures
# hadolint ignore=SC2094,SC2206
RUN ARCHS=(${CROSS_COMPILE_ARCHS}) && \
    ARCHS_LIST=$(IFS=,; echo "${ARCHS[*]}") && \
    for ARCH in "${ARCHS[@]}"; do \
    dpkg --add-architecture "$ARCH"; \
    done \
    && sed -i 's/deb /deb [arch="amd64"] /' /etc/apt/sources.list \
    && grep -E "^deb " /etc/apt/sources.list | sed "s/amd64/${ARCHS_LIST}/" \
    | sed 's|http://.*.ubuntu.com/ubuntu/|http://ports.ubuntu.com/|' \
    >> /etc/apt/sources.list

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
