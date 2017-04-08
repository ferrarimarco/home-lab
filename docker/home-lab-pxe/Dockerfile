FROM ferrarimarco/pxe:dev-latest

LABEL maintainer "ferrari.marco@gmail.com"

RUN apt-get update \
  && apt-get install p7zip-full

WORKDIR /var/lib/tftpboot
ENV UBUNTU_SERVER_MAJOR_MINOR_VERSION 16.04
ENV UBUNTU_SERVER_POINT_VERSION 2
ENV UBUNTU_SERVER_VERSION $UBUNTU_SERVER_MAJOR_MINOR_VERSION.$UBUNTU_SERVER_POINT_VERSION

RUN mkdir ubuntu \
  && wget http://releases.ubuntu.com/$UBUNTU_SERVER_MAJOR_MINOR_VERSION/ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso \

RUN 7z x ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso \
RUN rm ubuntu-$UBUNTU_SERVER_VERSION-server-amd64.iso

RUN apt-get remove --purge p7zip-full
