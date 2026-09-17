#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC1091,SC1094
. ./scripts/common.sh

# Format the given paths (default: the whole repository) with the formatters
# that super-linter runs in check mode, taken from the same pinned container
# image, so results match what CI validates. Directories go through every
# formatter; single files only go through the formatters that support their
# file type.

if [ "$#" -gt 0 ]; then
  PATHS_TO_FORMAT=("$@")
else
  PATHS_TO_FORMAT=(.)
fi

LINTER_CONTAINER_IMAGE="$(get_super_linter_container_image)"

echo "Running formatter container image: ${LINTER_CONTAINER_IMAGE}"

MARKDOWNLINT_TARGETS=()
PRETTIER_TARGETS=()
SHFMT_TARGETS=()
TERRAFORM_TARGETS=()
TEXTLINT_TARGETS=()

for PATH_TO_FORMAT in "${PATHS_TO_FORMAT[@]}"; do
  if [ -d "${PATH_TO_FORMAT}" ]; then
    MARKDOWNLINT_TARGETS+=("${PATH_TO_FORMAT}")
    PRETTIER_TARGETS+=("${PATH_TO_FORMAT}")
    SHFMT_TARGETS+=("${PATH_TO_FORMAT}")
    TERRAFORM_TARGETS+=("${PATH_TO_FORMAT}")
    TEXTLINT_TARGETS+=("${PATH_TO_FORMAT}")
  else
    case "${PATH_TO_FORMAT}" in
    *.md)
      MARKDOWNLINT_TARGETS+=("${PATH_TO_FORMAT}")
      PRETTIER_TARGETS+=("${PATH_TO_FORMAT}")
      TEXTLINT_TARGETS+=("${PATH_TO_FORMAT}")
      ;;
    *.txt)
      PRETTIER_TARGETS+=("${PATH_TO_FORMAT}")
      TEXTLINT_TARGETS+=("${PATH_TO_FORMAT}")
      ;;
    *.sh | *.bash)
      SHFMT_TARGETS+=("${PATH_TO_FORMAT}")
      ;;
    *.tf | *.tfvars)
      TERRAFORM_TARGETS+=("${PATH_TO_FORMAT}")
      ;;
    *.json | *.js | *.mjs | *.cjs | *.yaml | *.yml | *.html | *.css)
      PRETTIER_TARGETS+=("${PATH_TO_FORMAT}")
      ;;
    *)
      echo "Warning: no formatter configured for ${PATH_TO_FORMAT}. Skipping it."
      ;;
    esac
  fi
done

run_formatter() {
  local FORMATTER_COMMAND="${1}"
  echo "Running: ${FORMATTER_COMMAND}"
  docker run \
    --entrypoint /bin/bash \
    --rm \
    --volume "$(pwd)":/tmp/lint \
    --workdir /tmp/lint \
    "${LINTER_CONTAINER_IMAGE}" \
    -c "${FORMATTER_COMMAND}"
}

quote_paths() {
  printf '%q ' "$@"
}

if [ "${#PRETTIER_TARGETS[@]}" -gt 0 ]; then
  # Exclude the generated docs site output and the super-linter output
  # directory, matching the FILTER_REGEX_EXCLUDE and gitignore setup that
  # super-linter runs with.
  run_formatter "prettier --write $(quote_paths "${PRETTIER_TARGETS[@]}") '!docs/**' '!super-linter-output/**'"
fi

if [ "${#MARKDOWNLINT_TARGETS[@]}" -gt 0 ]; then
  # markdownlint fails when issues that --fix cannot resolve remain: fix them
  # manually.
  run_formatter "markdownlint --config config/lint/.markdown-lint.yaml --fix --ignore docs --ignore super-linter-output $(quote_paths "${MARKDOWNLINT_TARGETS[@]}")"
fi

if [ "${#SHFMT_TARGETS[@]}" -gt 0 ]; then
  run_formatter "shfmt --write $(quote_paths "${SHFMT_TARGETS[@]}")"
fi

if [ "${#TEXTLINT_TARGETS[@]}" -gt 0 ]; then
  run_formatter "textlint --config /action/lib/.automation/.textlintrc --fix $(quote_paths "${TEXTLINT_TARGETS[@]}")"
fi

if [ "${#TERRAFORM_TARGETS[@]}" -gt 0 ]; then
  run_formatter "terraform fmt -recursive $(quote_paths "${TERRAFORM_TARGETS[@]}")"
fi

echo "The following super-linter fixers are not covered by this script: ${FORMAT_SCRIPT_DELEGATED_FIXERS[*]}"
echo "Run LINTER_CONTAINER_FIX_MODE=true scripts/lint.sh to apply them."
