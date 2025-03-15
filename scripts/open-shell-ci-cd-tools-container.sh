#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC1091,SC1094
. ./scripts/common.sh

build_cd_container

docker run \
  --rm \
  -it \
  --entrypoint "/bin/bash" \
  --user "0:0" \
  --volume "$(pwd):/source-repository" \
  --volume "$(pwd)/docker/ci-cd-tools/package.json:/app/package.json" \
  --volume "$(pwd)/docker/ci-cd-tools/package-lock.json:/app/package-lock.json" \
  "${CD_CONTAINER_URL}"
