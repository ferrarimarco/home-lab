FROM ghcr.io/restic/restic:0.17.1@sha256:5a026985e1dec5b2e8f097686f97636f71cb7d6072ddc43acbe1f305f3fa6797

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
