FROM ghcr.io/restic/restic:0.16.5

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
