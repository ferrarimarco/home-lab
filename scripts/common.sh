#!/usr/bin/env sh

set -o nounset
set -o errexit

# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
EXIT_OK=0
ERR_GENERIC=1
ERR_VARIABLE_NOT_DEFINED=2
ERR_MISSING_DEPENDENCY=3
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_ARGUMENT_EVAL_ERROR=4
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_GOOGLE_APPLICATION_CREDENTIALS_NOT_FOUND=5
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_DIRECTORY_NOT_FOUND=6
# Ignoring SC2034 because this variable is used in other scripts
# shellcheck disable=SC2034
ERR_ARCHIVE_NOT_SUPPORTED=6

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

check_optional_argument() {
  ARGUMENT_VALUE="${1}"
  ARGUMENT_DESCRIPTION="${2}"

  if [ -z "${ARGUMENT_VALUE}" ]; then
    echo "[OK]: optional ${ARGUMENT_DESCRIPTION} is not defined."
    RET_CODE=1
  else
    echo "[OK]: optional ${ARGUMENT_DESCRIPTION} value is defined: ${ARGUMENT_VALUE}"
    RET_CODE=0
  fi

  unset ARGUMENT_NAME
  unset ARGUMENT_VALUE

  return ${RET_CODE}
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

is_linux() {
  os_name="$(uname -s)"
  if test "${os_name#*"Linux"}" != "$os_name"; then
    unset os_name
    return ${EXIT_OK}
  else
    unset os_name
    return ${ERR_GENERIC}
  fi
}

is_macos() {
  os_name="$(uname -s)"
  if test "${os_name#*"Darwin"}" != "$os_name"; then
    unset os_name
    return 0
  else
    unset os_name
    return ${ERR_GENERIC}
  fi
}

print_exit_statuses() {
  echo
  echo "EXIT STATUS"
  echo
  echo "  ${EXIT_OK} on correct execution."
  echo "  ${ERR_GENERIC} when an error occurs, and there's no specific error code to handle it."
  echo "  ${ERR_VARIABLE_NOT_DEFINED} when a parameter or a variable is not defined, or empty."
  echo "  ${ERR_MISSING_DEPENDENCY} when a required dependency is missing."
  echo "  ${ERR_ARGUMENT_EVAL_ERROR} when there was an error while evaluating the program options."
  echo
}
