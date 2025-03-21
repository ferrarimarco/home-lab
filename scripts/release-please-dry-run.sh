#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC1091,SC1094
. ./scripts/common.sh

RELEASE_PLEASE_TARGET_BRANCH="${GITHUB_HEAD_REF:-$(git branch --show-current)}"

build_cd_container

check_github_token_file

echo "Running release-please against branch: ${RELEASE_PLEASE_TARGET_BRANCH}"
docker run \
  --rm \
  --volume "$(pwd):/source-repository" \
  "${CD_CONTAINER_URL}" \
  release-please \
  release-pr \
  --config-file .github/release-please/release-please-config.json \
  --dry-run \
  --manifest-file .github/release-please/.release-please-manifest.json \
  --repo-url ferrarimarco/home-lab \
  --target-branch "${RELEASE_PLEASE_TARGET_BRANCH}" \
  --token "$(cat "${GITHUB_TOKEN_PATH}")" \
  --trace
