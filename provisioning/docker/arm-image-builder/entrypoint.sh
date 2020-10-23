#!/usr/bin/env sh

set -o nounset
set -o errexit

echo "This script has been invoked with: $0 $*"

if ! TEMP="$(getopt -o e:o: --long entrypoint:,options: \
  -n 'entrypoint' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

entrypoint=
options=

while true; do
  echo "Decoding parameter ${1}..."
  case "${1}" in
  -e | --entrypoint)
    echo "Found entrypoint parameter"
    entrypoint="${2}"
    shift 2
    ;;
  -o | --options)
    echo "Found options parameter"
    options="${2}"
    shift 2
    ;;
  --)
    echo "No more parameters to decode"
    shift
    break
    ;;
  *) break ;;
  esac
done

echo "Registering qemu-*-static for all supported processors except the current one..."
bash /register --reset -p yes >/dev/null 2>&1

echo "Running ${entrypoint} ${options}..."
sh -c "${entrypoint} ${options}"
