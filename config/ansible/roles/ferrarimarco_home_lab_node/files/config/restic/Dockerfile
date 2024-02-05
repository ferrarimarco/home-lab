FROM ghcr.io/restic/restic:0.16.4

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
