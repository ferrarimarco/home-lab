FROM ghcr.io/restic/restic:0.16.4@sha256:c38ed2f65732b2210772a70365ea7652ca8d2fa795579366a78c152b037a3522

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
