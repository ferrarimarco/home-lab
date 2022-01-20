FROM ubuntu:20.04

# Setting TZ has issues for now: https://bugs.launchpad.net/ubuntu/+source/tzdata/+bug/1899343
RUN DEBIAN_FRONTEND=noninteractive \
  TERM=linux \
  TZ=Etc/UTC \
  echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections \
  && apt-get update \
  && apt-get \
  --no-install-recommends --yes install \
  ca-certificates \
  cloud-init \
  dbus \
  kmod \
  locales \
  lsb-release \
  openssh-client \
  ntp \
  systemd \
  udev \
  && rm -rf /var/lib/apt/lists/* \
  && ln -s "$(command -v systemd)" /sbin/init

# Don't clean up apt cache
RUN rm /etc/apt/apt.conf.d/docker-clean

# tell systemd that it is in docker
# https://www.freedesktop.org/software/systemd/man/systemd-detect-virt.html
ENV container docker
# systemd exits on SIGRTMIN+3, not SIGTERM
# https://www.freedesktop.org/software/systemd/man/systemd.html#SIGRTMIN+3
STOPSIGNAL SIGRTMIN+3
ENTRYPOINT [ "/sbin/init" ]

RUN echo 'root:root' | chpasswd

COPY etc/ /etc/

RUN for f in /etc/cloud/cloud.cfg.d/*.cfg.yaml; do mv -- "${f}" "${f%.yaml}"; done
