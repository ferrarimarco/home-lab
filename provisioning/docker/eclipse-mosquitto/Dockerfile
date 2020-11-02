FROM eclipse-mosquitto:1.6.12-openssl as eclipse-mosquitto

FROM python:3.9.0-alpine3.12

COPY --from=eclipse-mosquitto /usr/bin/mosquitto_sub /usr/bin/
COPY --from=eclipse-mosquitto /usr/bin/mosquitto_passwd /usr/bin/
COPY --from=eclipse-mosquitto /usr/bin/mosquitto_pub /usr/bin/
COPY --from=eclipse-mosquitto /usr/bin/mosquitto_rr /usr/bin/

COPY --from=eclipse-mosquitto /usr/sbin/mosquitto /usr/sbin/

COPY --from=eclipse-mosquitto /usr/lib/libmosquitto.so.1 /usr/lib/

# We use requirements.txt files so that we can watch it for dependency updates.
COPY requirements.txt requirements.txt

RUN apk add --no-cache \
    libressl-dev

RUN apk add --no-cache --virtual .build_deps \
    build-base \
    curl \
    libffi-dev \
    musl-dev \
    python3-dev \
    && pip3 install --no-cache-dir -r requirements.txt \
    && rm requirements.txt \
    && mkdir -p "/etc/cloud-iot-core/certificates" \
    && curl https://pki.goog/roots.pem --output "/etc/cloud-iot-core/certificates/iot-core-root-ca.pem" \
    && apk del .build_deps

ARG CONFIGURATION_DIRECTORY_PATH

# Copy configuration files
COPY "$CONFIGURATION_DIRECTORY_PATH"/ /

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]

# Unset the CMD
CMD []
