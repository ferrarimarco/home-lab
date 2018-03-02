#!/bin/sh

set -e

if ! TEMP="$(getopt -o vdm: --long docker-compose-path: -n 'start-network-stack' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

docker_compose_path=

while true; do
  case "$1" in
    -c | --docker-compose-path ) docker_compose_path="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

docker stack deploy --compose-file "$docker_compose_path" network
