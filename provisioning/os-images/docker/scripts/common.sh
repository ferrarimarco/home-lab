#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
EXIT_OK=0

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_GENERIC=1
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_VARIABLE_NOT_DEFINED=2
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_MISSING_DEPENDENCY=3
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_ARGUMENT_EVAL_ERROR=4
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_ARCHIVE_NOT_SUPPORTED=5

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
HELP_DESCRIPTION="show this help message and exit"

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
