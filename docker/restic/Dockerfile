# Currently, there's no arm64 restic image, so
# we build one and update restic to the latest available version
# using its built-in self-update command

# Ref: https://github.com/restic/restic/issues/2359

FROM ghcr.io/restic/restic:0.16.0

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
