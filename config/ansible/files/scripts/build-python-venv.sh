#!/usr/bin/env sh

set -o errexit
set -o nounset

PYTHON_VENV_PATH="${1}"
PIP_REQUIREMENTS_FILE="${2}"

echo "Build python virtual environment: ${PYTHON_VENV_PATH} if necessary. pip requirements file: ${PIP_REQUIREMENTS_FILE}"

if [ ! -e "${PIP_REQUIREMENTS_FILE}" ]; then
  echo "pip requirements file not found: ${PIP_REQUIREMENTS_FILE}"
  exit 1
fi

if [ ! -d "${PYTHON_VENV_PATH}" ]; then
  mkdir \
    --parents \
    --verbose \
    "${PYTHON_VENV_PATH}"
fi

STORED_PIP_REQUIREMENTS_FILE_HASH_PATH="${PYTHON_VENV_PATH}/.pip-requirements-file-hash"

# Include the Python interpreter version in the stamp so that upgrading the
# system Python invalidates the virtual environment, which symlinks it.
CURRENT_PIP_REQUIREMENTS_FILE_HASH="$(md5sum "${PIP_REQUIREMENTS_FILE}" | awk '{print $1}') $(python3 --version)"
echo "Current pip requirements file hash (${PIP_REQUIREMENTS_FILE}): ${CURRENT_PIP_REQUIREMENTS_FILE_HASH}"

STORED_PIP_REQUIREMENTS_FILE_HASH=""
if [ -f "${STORED_PIP_REQUIREMENTS_FILE_HASH_PATH}" ]; then
  STORED_PIP_REQUIREMENTS_FILE_HASH=$(cat "${STORED_PIP_REQUIREMENTS_FILE_HASH_PATH}")
fi

# Virtual Environment Creation (if necessary)
if [ ! -x "${PYTHON_VENV_PATH}/bin/pip3" ] || [ "${CURRENT_PIP_REQUIREMENTS_FILE_HASH}" != "${STORED_PIP_REQUIREMENTS_FILE_HASH}" ]; then
  echo "The ${PYTHON_VENV_PATH} Python virtual environment is missing or broken, or the contents of the pip requirements file (${PIP_REQUIREMENTS_FILE}) have changed. Creating or updating the ${PYTHON_VENV_PATH} Python virtual environment."

  python3 \
    -m venv \
    --clear \
    --system-site-packages \
    --upgrade-deps \
    "${PYTHON_VENV_PATH}"

  "${PYTHON_VENV_PATH}"/bin/pip3 install \
    --requirement "${PIP_REQUIREMENTS_FILE}"

  echo "${CURRENT_PIP_REQUIREMENTS_FILE_HASH}" >"${STORED_PIP_REQUIREMENTS_FILE_HASH_PATH}"
else
  echo "The contents of the pip requirements file (${PIP_REQUIREMENTS_FILE}) did not change since the last run. Skipping the ${PYTHON_VENV_PATH} Python virtual environment creation or update."
fi
