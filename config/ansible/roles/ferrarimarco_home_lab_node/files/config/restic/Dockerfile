FROM ghcr.io/restic/restic:0.18.0@sha256:c34f8216c1536fc6a1677d088b195b9353e0f1615c842407efefb84ed761c435

COPY ./entrypoint.sh /bin/entrypoint.sh

RUN chmod +x "/bin/entrypoint.sh"

ENTRYPOINT [ "/bin/entrypoint.sh" ]
