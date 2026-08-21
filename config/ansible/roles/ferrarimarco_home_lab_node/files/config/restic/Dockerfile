FROM ghcr.io/restic/restic:0.19.1@sha256:2f0373803493361f9304a57150d464677f69a9dad487afec202105aafb2592f2

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
