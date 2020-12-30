#!/bin/sh

set -e

echo "Loading the bearer token from the metadata server..."
curl http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token -H "Metadata-Flavor: Google" | jq -r '.access_token' >/var/run/secrets/gke-metadata/bearer-token

echo "Starting OpenTelemetry Collector..."
/otelcontribcol --config /etc/otel/config.yaml
