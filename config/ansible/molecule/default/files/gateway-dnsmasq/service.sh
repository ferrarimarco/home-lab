#!/bin/sh

# Stands in for the service command of the gateway's firmware on the test
# instance: it accepts the one call the gateway role makes, so any other call
# fails the write task.

set -o errexit
set -o nounset

if [ "$*" != "restart_dnsmasq" ]; then
  echo "Unsupported service arguments: $*" >&2
  exit 1
fi
