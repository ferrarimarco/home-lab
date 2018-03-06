#!/bin/sh

if ! TEMP="$(getopt -o vdm: --long manager-ip: -n 'init-docker-swarm-worker' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

manager_ip=
swarm_token_path="/docker-swarm/swarm-token"
swarm_worker_token_path="$swarm_token_path/worker"

while true; do
  case "$1" in
    -m | --manager-ip ) manager_ip="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ ! $(docker info | grep "Swarm: active") ]; then
  docker swarm join \
  --token "$(cat  "$swarm_worker_token_path")" \
  "$manager_ip:2377":2377
fi
