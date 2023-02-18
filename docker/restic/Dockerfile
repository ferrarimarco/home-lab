# Currently, there's no arm64 restic image, so
# we build one and update restic to the latest available version
# using its built-in self-update command

# Ref: https://github.com/restic/restic/issues/2359

# Not really using this now, but it's useful for automated dependency updates
FROM restic/restic:0.15.1 as restic

FROM debian:bullseye

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
    && restic version

ENTRYPOINT [ "restic" ]
