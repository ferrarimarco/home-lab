FROM ferrarimarco/pxe:dev-latest

LABEL maintainer "ferrari.marco@gmail.com"

# Install the necessary packages
RUN apt-get update \
  && apt-get install -y \
    p7zip-full

# Stop the dnsmasq service that is automatically started after installing the
# corresponding package
RUN service dnsmasq stop

ENV UBUNTU_SERVER_MAJOR_MINOR_VERSION 16.04
ENV UBUNTU_SERVER_POINT_VERSION 2
ENV UBUNTU_SERVER_VERSION $UBUNTU_SERVER_MAJOR_MINOR_VERSION.$UBUNTU_SERVER_POINT_VERSION

# Download Ubuntu 16.04 amd64
RUN mkdir -p /var/lib/tftpboot/ubuntu/16.04/$UBUNTU_SERVER_VERSION-server-amd64
WORKDIR /var/lib/tftpboot/ubuntu/16.04/$UBUNTU_SERVER_VERSION-server-amd64
RUN wget http://releases.ubuntu.com/$UBUNTU_SERVER_MAJOR_MINOR_VERSION/ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso \
  && 7z x ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso \
  && rm ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso

# Download Ubuntu 16.04 i386
RUN mkdir -p /var/lib/tftpboot/ubuntu/16.04/$UBUNTU_SERVER_VERSION-server-i386
WORKDIR /var/lib/tftpboot/ubuntu/16.04/$UBUNTU_SERVER_VERSION-server-i386
RUN wget http://releases.ubuntu.com/$UBUNTU_SERVER_MAJOR_MINOR_VERSION/ubuntu-$UBUNTU_SERVER_VERSION-server-i386.iso \
  && 7z x ubuntu-$UBUNTU_SERVER_VERSION-server-i386.iso \
  && rm ubuntu-$UBUNTU_SERVER_VERSION-server-i386.iso

# Cleanup
RUN apt-get remove -y --purge \
    p7zip-full \
  && rm -rf /var/lib/apt/lists/*

COPY tftpboot/ /var/lib/tftpboot
COPY etc/ /etc/

# Start dnsmasq. It picks up default configuration from /etc/dnsmasq.conf and
# /etc/default/dnsmasq plus any command line switch
ENTRYPOINT ["dnsmasq", "--no-daemon"]
