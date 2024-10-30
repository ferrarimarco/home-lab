FROM ghcr.io/restic/restic:0.17.2@sha256:ac8034615699a22c258184d04d79524833e2884c7b85c0f9b1ee716e6530505c

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
