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

# Create the script here because we build this locally on the host and we need a Dockerfile
# that doesen't need other files and dependencies
RUN cat > /bin/entrypoint.sh <<EOF
#!/usr/bin/env sh

set -o errexit
set -o nounset

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

echo "This script (${SCRIPT_BASENAME}) has been invoked with: $0 $*"

restic version

echo "Restic repository file: ${RESTIC_REPOSITORY_FILE}"
echo "Restic repository: ${RESTIC_REPOSITORY}"

echo "Checking if the ${RESTIC_REPOSITORY} Restic repository needs to be initalized."

if restic snapshots; then
  echo "The ${RESTIC_REPOSITORY} repository is already initialized."
else
  echo "Initializing the ${RESTIC_REPOSITORY} repository"
  restic --verbose init
fi

if [ "${RESTIC_ENABLE_BACKUP}" = "true" ]; then
  echo "Backing up ${RESTIC_DIRECTORIES_TO_BACKUP}"
  restic --verbose backup "${RESTIC_DIRECTORIES_TO_BACKUP}"
fi

if [ "${RESTIC_ENABLE_REPOSITORY_CHECK}" = "true" ]; then
  echo "Checking the integrity of ${RESTIC_REPOSITORY}"
  restic --verbose check
fi
EOF \
    && chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
