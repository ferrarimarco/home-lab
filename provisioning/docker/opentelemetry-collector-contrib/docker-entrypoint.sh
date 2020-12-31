#!/bin/sh

set -e

BEARER_TOKEN_PATH="/var/run/secrets/gke-metadata/bearer-token"
echo "Loading the bearer token from the metadata server and saving it to $BEARER_TOKEN_PATH..."
mkdir -p "$(dirname "$BEARER_TOKEN_PATH")"
curl http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token -H "Metadata-Flavor: Google" | jq -r '.access_token' >"$BEARER_TOKEN_PATH"

echo "Starting OpenTelemetry Collector (otelcontribcol) with arguments: $*"
/otelcontribcol "$@"
