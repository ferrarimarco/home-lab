FROM ferrarimarco/pxe:1.1.0

LABEL maintainer "ferrari.marco@gmail.com"

RUN apt-get update \
  && apt-get install p7zip-full

ENV UBUNTU_SERVER_MAJOR_MINOR_VERSION 16.04
ENV UBUNTU_SERVER_POINT_VERSION 2
ENV UBUNTU_SERVER_VERSION $UBUNTU_SERVER_MAJOR_MINOR_VERSION.$UBUNTU_SERVER_POINT_VERSION

RUN mkdir -p /var/lib/tftpboot/ubuntu/16.04/$UBUNTU_SERVER_VERSION-server-amd64
WORKDIR /var/lib/tftpboot/ubuntu/16.04/$UBUNTU_SERVER_VERSION-server-amd64
RUN wget http://releases.ubuntu.com/$UBUNTU_SERVER_MAJOR_MINOR_VERSION/ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso \
  && 7z x ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso \
  && rm ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso

RUN apt-get remove -y --purge p7zip-full
