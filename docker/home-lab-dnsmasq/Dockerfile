FROM ubuntu:16.04

LABEL maintainer "ferrari.marco@gmail.com"

# Install the necessary packages
RUN apt-get update \
  && apt-get install -y \
    dnsmasq \
    pxelinux \
    syslinux-common \
    wget

# Stop the dnsmasq service that is automatically started after installing the
# corresponding package
RUN service dnsmasq stop

# Setup DNSMASQ
COPY etc/ /etc

# Start dnsmasq. It picks up default configuration from /etc/dnsmasq.conf and
# /etc/default/dnsmasq plus any command line switch
ENTRYPOINT ["dnsmasq", "--no-daemon"]
