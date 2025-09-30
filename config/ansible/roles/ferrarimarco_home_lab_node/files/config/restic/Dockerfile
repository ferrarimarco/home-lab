FROM ghcr.io/restic/restic:0.18.1@sha256:c1958a2a1c8614f5c317347c2aaddd9f426076f0521430b55509eba43d7516ee

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
