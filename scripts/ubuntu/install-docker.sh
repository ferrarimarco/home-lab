#!/bin/sh

if ! TEMP="$(getopt -o vdm: --long user: -n 'install-docker' -- "$@")" ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

user=

while true; do
  case "$1" in
    -u | --user ) user="$2"; shift 2 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

if which docker >/dev/null 2>&1 ; then
  echo "Docker is already installed"
else
  curl -sSL https://get.docker.com | sh
  usermod -aG docker "$user"
fi
