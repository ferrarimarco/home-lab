FROM otel/opentelemetry-collector-contrib:0.18.0 as opentelemetry-collector-contrib

FROM alpine:3.13.0

RUN apk --no-cache add \
    ca-certificates \
    curl \
    jq

COPY --from=opentelemetry-collector-contrib /otelcontribcol /

EXPOSE 55680 55679

COPY "docker-entrypoint.sh"/ /
RUN chmod a+x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
