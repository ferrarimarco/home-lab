#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo "This script has been invoked with: $0 $*"

/snap/bin/microk8s status --wait-ready
/snap/bin/microk8s enable dns ingress metallb:10.254.0.0/16 storage
/snap/bin/microk8s status --wait-ready
