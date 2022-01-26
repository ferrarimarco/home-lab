FROM ubuntu:20.04

SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
    TERM=linux \
    TZ=Etc/UTC \
    apt-get \
    --no-install-recommends --yes install \
    ca-certificates \
    cloud-init \
    dbus \
    fuse \
    kmod \
    locales \
    lsb-release \
    ntp \
    openssh-client \
    openssh-server \
    pollinate \
    snap-confine \
    snapd \
    squashfuse \
    sudo \
    systemd \
    udev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(command -v systemd)" /sbin/init \
    && dpkg-divert --local --rename --add /sbin/udevadm \
    && ln -s /bin/true /sbin/udevadm \
    && systemctl enable snapd

# Don't clean up apt cache
RUN rm /etc/apt/apt.conf.d/docker-clean

# tell systemd that it is in docker
# https://www.freedesktop.org/software/systemd/man/systemd-detect-virt.html
ENV container docker
# systemd exits on SIGRTMIN+3, not SIGTERM
# https://www.freedesktop.org/software/systemd/man/systemd.html#SIGRTMIN+3
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT [ "/sbin/init" ]

# Set the root user password to a known value that we can use to login as needed
RUN echo 'root:root' | chpasswd

COPY etc/ /etc/

# Cloud-init supplemental configuration file are written in YAML, but require a
# .cfg extension. Rename them after copying in the image.
RUN for f in /etc/cloud/cloud.cfg.d/*.cfg.yaml; do mv -- "${f}" "${f%.yaml}"; done
