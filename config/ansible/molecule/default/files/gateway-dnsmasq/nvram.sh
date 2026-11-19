#!/bin/sh

# Stands in for the nvram command of the gateway's firmware on the test
# instance, with the subcommands the gateway role calls: one file per variable,
# and an empty line for a variable that was never set, as the router prints.

set -o errexit
set -o nounset

NVRAM_DIRECTORY="/var/lib/gateway-nvram"

case "${1:-}" in
get)
  if [ -f "${NVRAM_DIRECTORY}/${2}" ]; then
    cat "${NVRAM_DIRECTORY}/${2}"
  else
    echo
  fi
  ;;
set)
  printf '%s\n' "${2#*=}" >"${NVRAM_DIRECTORY}/${2%%=*}"
  ;;
commit) ;;
*)
  echo "Unsupported nvram arguments: $*" >&2
  exit 1
  ;;
esac
