#!/bin/sh

if ! TEMP="$(getopt -o vdm: --long manager-ip: -n 'init-docker-swarm-manager' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

interface="$(find /sys/class/net \( -not -name lo -and -not -name 'docker*' -and -not -type d \) -printf "%f\\n" | sort | sed -n '2p')"
manager_ip=
swarm_token_path="/docker-swarm/swarm-token"
swarm_manager_token_path="$swarm_token_path/manager"
swarm_worker_token_path="$swarm_token_path/worker"

while true; do
  case "$1" in
    -m | --manager-ip ) manager_ip="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if [ ! -d "$swarm_token_path" ]; then
  if [ ! "$(docker info | grep -q "Swarm: active")" ]; then
    echo "Initializing Swarm as manager on $interface interface"
    docker swarm init --advertise-addr "$interface:2377"
  fi

  echo "Initializing Swarm token"
  mkdir -p "$swarm_token_path"
  chmod 777 "$swarm_token_path"

  docker swarm join-token -q manager > "$swarm_manager_token_path"
  echo "Swarm Manager Token: $(cat "$swarm_manager_token_path")"
  docker swarm join-token -q worker > "$swarm_worker_token_path"
  echo "Swarm Worker Token: $(cat "$swarm_worker_token_path")"
else
  echo "Joining existing swarm as manager. Swarm IP: $manager_ip"
  docker swarm join \
  --token "$(cat  "$swarm_manager_token_path")" \
  "$manager_ip:2377"
fi
