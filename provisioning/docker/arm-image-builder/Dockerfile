FROM multiarch/qemu-user-static:register AS register

FROM ubuntu:focal

ENV CROSS_COMPILE_ARCHS "arm64 armhf"

# Allow us to install packages for cross-compiling architectures
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
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

# some scripts have a hard dependency on sudo :(
# hadolint ignore=DL3008
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    bmap-tools \
    build-essential \
    ca-certificates \
    debootstrap \
    dirmngr \
    dosfstools \
    gdisk \
    git \
    gnupg \
    gnupg-l10n \
    gnupg-utils \
    gpg \
    gpg-agent \
    gpg-wks-client \
    gpg-wks-server \
    gpgconf \
    gpgsm \
    kpartx \
    libarchive-tools \
    libassuan0 \
    libksba8 \
    libnpth0 \
    m4 \
    parted \
    pinentry-curses \
    psmisc \
    pv \
    qemu \
    qemu-user-static \
    qemu-utils \
    sudo \
    wget \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install armhf-specific packages
# hadolint ignore=DL3008
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends \
    binutils:armhf \
    cpp:armhf \
    g++:armhf \
    make:armhf \
    && rm -rf /var/lib/apt/lists/*

COPY --from=register /register /register
COPY --from=register /qemu-binfmt-conf.sh /qemu-binfmt-conf.sh

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
