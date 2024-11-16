FROM ghcr.io/restic/restic:0.17.3@sha256:b89484687c77dfe09d7415a0ced4ad1e820bfba0f8e5c97881e697299d6b734b

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
