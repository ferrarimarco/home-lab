FROM ferrarimarco/pxe:1.3.0

LABEL maintainer "ferrari.marco@gmail.com"

ENV UBUNTU_SERVER_VERSION xenial
ENV UBUNTU_SERVER_VERSION_REMOTE_DIRECTORY $UBUNTU_SERVER_VERSION-updates

RUN mkdir -p /var/lib/tftpboot/ubuntu/$UBUNTU_SERVER_VERSION-server-amd64

WORKDIR /var/lib/tftpboot/ubuntu/$UBUNTU_SERVER_VERSION-server-amd64

RUN \
  apk add --update tar \
  && wget -q "http://archive.ubuntu.com/ubuntu/dists/$UBUNTU_SERVER_VERSION_REMOTE_DIRECTORY/main/installer-amd64/current/images/netboot/netboot.tar.gz" \
  && tar -xvzf netboot.tar.gz \
  && rm netboot.tar.gz \
  && apk del tar \
  && rm -rf /var/cache/apk/*

COPY tftpboot/ /var/lib/tftpboot
COPY etc/ /etc/

# Start dnsmasq. It picks up default configuration from /etc/dnsmasq.conf and
# /etc/default/dnsmasq plus any command line switch
ENTRYPOINT ["dnsmasq", "--keep-in-foreground", "--log-facility=-"]

VOLUME ["/var/lib/misc"]
