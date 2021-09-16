#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

EXIT_OK=0

ERR_GENERIC=1
ERR_VARIABLE_NOT_DEFINED=2
ERR_MISSING_DEPENDENCY=3
ERR_ARGUMENT_EVAL_ERROR=4
ERR_ARCHIVE_NOT_SUPPORTED=5

echo "This script has been invoked with: $0 $*"

check_argument() {
  ARGUMENT_VALUE="${1}"
  ARGUMENT_DESCRIPTION="${2}"

  if [ -z "${ARGUMENT_VALUE}" ]; then
    echo "[ERROR]: ${ARGUMENT_DESCRIPTION} is not defined. Run this command with the -h option to get help. Terminating..."
    exit ${ERR_VARIABLE_NOT_DEFINED}
  else
    echo "[OK]: ${ARGUMENT_DESCRIPTION} value is defined: ${ARGUMENT_VALUE}"
  fi

  unset ARGUMENT_NAME
  unset ARGUMENT_VALUE
}

check_exec_dependency() {
  EXECUTABLE_NAME="${1}"

  if ! command -v "${EXECUTABLE_NAME}" >/dev/null 2>&1; then
    echo "[ERROR]: ${EXECUTABLE_NAME} command is not available, but it's needed. Make it available in PATH and try again. Terminating..."
    exit ${ERR_MISSING_DEPENDENCY}
  else
    echo "[OK]: ${EXECUTABLE_NAME} is available in PATH, pointing to: $(command -v "${EXECUTABLE_NAME}")"
  fi

  unset EXECUTABLE_NAME
}

echo "Checking if the necessary dependencies are available..."
check_exec_dependency "cloud-init"
check_exec_dependency "cloud-localds"
check_exec_dependency "getopt"

# Doesn't follow symlinks, but it's likely expected for most users
SCRIPT_BASENAME="$(basename "${0}")"

CLOUD_INIT_DATASOURCE_OUTPUT_DIRECTORY_PATH_DESCRIPTION="path to the directory that will contain the resulting output"
CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH_DESCRIPTION="path to the directory containing the cloud-init datasource files"

usage() {
  echo
  echo "${SCRIPT_BASENAME} - Build OS images."
  echo
  echo "USAGE"
  echo "  ${SCRIPT_BASENAME} [options]"
  echo
  echo "OPTIONS"
  echo "  -d | --cloud-init-datasource-source-directory: ${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH_DESCRIPTION}"
  echo "  -o | --cloud-init-datasource-output-directory: ${CLOUD_INIT_DATASOURCE_OUTPUT_DIRECTORY_PATH_DESCRIPTION}"
  echo "  -h | --help: show this help message and exit"
  echo
  echo "EXIT STATUS"
  echo
  echo "  ${EXIT_OK} on correct execution."
  echo "  ${ERR_GENERIC} when an error occurs, and there's no specific error code to handle it."
  echo "  ${ERR_VARIABLE_NOT_DEFINED} when a parameter or a variable is not defined, or empty."
  echo "  ${ERR_MISSING_DEPENDENCY} when a required dependency is missing."
  echo "  ${ERR_ARGUMENT_EVAL_ERROR} when there was an error while evaluating the program options."
  echo "  ${ERR_ARCHIVE_NOT_SUPPORTED} when the archive is not supported."
}

if ! TEMP="$(getopt -o d:ho: --long cloud-init-datasource-output-directory:,cloud-init-datasource-source-directory:,help \
  -n 'build' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

CLOUD_INIT_DATASOURCE_OUTPUT_DIRECTORY_PATH=
CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH=

while true; do
  echo "Decoding parameter ${1}..."
  case "${1}" in
  -d | --cloud-init-datasource-source-directory)
    CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH="${2}"
    shift 2
    ;;
  -o | --cloud-init-datasource-output-directory)
    CLOUD_INIT_DATASOURCE_OUTPUT_DIRECTORY_PATH="${2}"
    shift 2
    ;;
  --)
    echo "No more parameters to decode"
    shift
    break
    ;;
  -h | --help | *)
    usage
    exit ${EXIT_OK}
    break
    ;;
  esac
done

echo "Checking if the necessary parameters are set..."
check_argument "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}" "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH_DESCRIPTION}"

echo "Validating cloud-init configuration file..."
cloud-init devel schema --config-file "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}/user-data.yaml"

TEMP_CLOUD_INIT_WORKING_DIRECTORY="$(mktemp -d)"

echo "Copying cloud-init configuration files to ${TEMP_CLOUD_INIT_WORKING_DIRECTORY}..."
cp \
  --force \
  --recursive \
  --verbose \
  "${CLOUD_INIT_DATASOURCE_SOURCE_DIRECTORY_PATH}/." "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}/"

echo "Removing the yaml file extension from cloud init datasource configuration files..."
mv --verbose "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}"/meta-data.yaml "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}"/meta-data
mv --verbose "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}"/user-data.yaml "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}"/user-data

echo "Generating the CIDATA ISO..."
cloud-localds "${CLOUD_INIT_DATASOURCE_OUTPUT_DIRECTORY_PATH}"/cloud-init-datasource.iso "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}"/user-data "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}"/meta-data

echo "Deleting the temporary working directory (${TEMP_CLOUD_INIT_WORKING_DIRECTORY})..."
rm \
  --force \
  --recursive \
  "${TEMP_CLOUD_INIT_WORKING_DIRECTORY}"

echo "Results saved in the temporary working directory: ${CLOUD_INIT_DATASOURCE_OUTPUT_DIRECTORY_PATH}"
