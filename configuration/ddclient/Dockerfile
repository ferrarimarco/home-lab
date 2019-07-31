FROM alpine:3.10.0

LABEL maintainer "ferrari.marco@gmail.com"

ARG DDCLIENT_VER="3.9.0"

RUN \
 echo "**** install build packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
	bzip2 \
	curl \
	gcc \
	make \
	tar \
	wget && \
 echo "**** install runtime packages ****" && \
 apk add --no-cache \
	inotify-tools \
	perl \
	perl-digest-sha1 \
	perl-io-socket-ssl \
	perl-json && \
 echo "***** install perl modules ****" && \
 curl -L http://cpanmin.us | perl - App::cpanminus && \
 cpanm JSON::Any && \
 echo "**** install ddclient ****" && \
 mkdir -p \
	/tmp/ddclient && \
 curl -o \
 /tmp/ddclient.tar.bz2 -L \
	"https://sourceforge.net/projects/ddclient/files/ddclient/ddclient-${DDCLIENT_VER}/ddclient-${DDCLIENT_VER}.tar.bz2/download" && \
 tar xf \
 /tmp/ddclient.tar.bz2 -C \
	/tmp/ddclient --strip-components=1 && \
 install -Dm755 /tmp/ddclient/ddclient /usr/bin/ && \
 echo "**** cleanup ****" && \
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/config/.cpanm \
	/root/.cpanm \
	/tmp/*

RUN mkdir -p \
  /var/cache/ddclient \
  /var/run/ddclient

ENTRYPOINT ["ddclient"]
CMD ["-debug", "-foreground", "-verbose"]
