FROM ghcr.io/restic/restic:0.16.5@sha256:66d5b38b78fe3226e1f70159ffd87f7579aace84d333e70969b5b1aa8747479e

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
