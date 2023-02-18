# Currently, there's no arm64 restic image, so
# we build one and update restic to the latest available version
# using its built-in self-update command

# Ref: https://github.com/restic/restic/issues/2359

FROM debian:bullseye

ARG RESTIC_CONTAINER_IMAGE_ID="restic/restic:0.15.1"

RUN apt-get update \
    && apt-get --assume-yes --no-install-recommends install \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
    && apt-get --assume-yes --no-install-recommends install \
    restic \
    tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && restic version \
    && restic self-update \
    && restic version \
    && echo "Input restic container image version: ${RESTIC_CONTAINER_IMAGE_ID}" \
    && DESIRED_RESTIC_VERSION="$(echo "${RESTIC_CONTAINER_IMAGE_ID}" | awk -F ':' '{print $2}')" \
    && echo "Desired restic version: ${DESIRED_RESTIC_VERSION}" \
    && CURRENT_RESTIC_VERSION="$(restic version | awk -F ' ' '{print $2}')" \
    && echo "Current restic version: ${CURRENT_RESTIC_VERSION}" \
    && if [ "${DESIRED_RESTIC_VERSION}" = "${CURRENT_RESTIC_VERSION}" ]; then echo "desired restic version matches with current version"; else echo "desired restic version doesn't match with current version"; exit 1; fi

ENTRYPOINT [ "restic" ]
