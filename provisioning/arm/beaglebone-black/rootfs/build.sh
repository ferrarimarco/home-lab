#!/usr/bin/env sh

set -e

echo "This script has been invoked with: $0 $*"

if ! TEMP="$(getopt -o b:c:n:r:u: --long branch-name:,build-configuration-name:,build-script-revision:,build-script-url:,commit-sha: \
  -n 'build' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

BRANCH_NAME=
build_configuration_name=
build_script_revision=
build_script_url=
COMMIT_SHA=

while true; do
  echo "Decoding parameter ${1}..."
  case "${1}" in
  -b | --branch-name)
    BRANCH_NAME="${2}"
    shift 2
    ;;
  -c | --commit-sha)
    COMMIT_SHA="${2}"
    shift 2
    ;;
  -n | --build-configuration-name)
    build_configuration_name="${2}"
    shift 2
    ;;
  -r | --build-script-revision)
    build_script_revision="${2}"
    shift 2
    ;;
  -u | --build-script-url)
    build_script_url="${2}"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  *) break ;;
  esac
done

echo "Cloning the ${build_script_url:?} Git repository..."
git clone "$build_script_url"
BUILD_SCRIPT_DIRECTORY_PATH="$(basename "$build_script_url" .git)"
CONFIGURATION_FILES_DESTINATION_PATH="${BUILD_SCRIPT_DIRECTORY_PATH}"/configs
SCRIPTS_DESTIONATION_PATH="${BUILD_SCRIPT_DIRECTORY_PATH}"/target/chroot

echo "Copying configuration files to ${CONFIGURATION_FILES_DESTINATION_PATH}..."
cp build-configs/* "${CONFIGURATION_FILES_DESTINATION_PATH}/"
echo "${CONFIGURATION_FILES_DESTINATION_PATH} contents: $(ls -alh "${CONFIGURATION_FILES_DESTINATION_PATH}")"

echo "Copying scripts to ${SCRIPTS_DESTIONATION_PATH}..."
cp chroot-scripts/* "${SCRIPTS_DESTIONATION_PATH}/"
echo "${SCRIPTS_DESTIONATION_PATH} contents: $(ls -alh "${SCRIPTS_DESTIONATION_PATH}")"

cd "${BUILD_SCRIPT_DIRECTORY_PATH}" || exit 1

echo "Checking out the ${build_script_revision:?} Git revision..."
# Disable the "detached HEAD" warning before checking out the revision
git config --global advice.detachedHead false
git checkout "${build_script_revision}"

echo "Building rootfs with the ${build_configuration_name:?} configuration"
./RootStock-NG.sh -c "${build_configuration_name}"

workspace_directory="$(pwd)"

PROJECT_FILE_PATH="${workspace_directory}/.project"
echo "Sourcing ${PROJECT_FILE_PATH}..."
# shellcheck source=/dev/null
. "${PROJECT_FILE_PATH}"

ROOTFS_SOURCE_PATH="${workspace_directory}/deploy/${deb_distribution:?}-${release:?}-${image_type:?}-${deb_arch:?}-${time:?}"

if [ ! -d "${ROOTFS_SOURCE_PATH}" ]; then
  echo "${ROOTFS_SOURCE_PATH} doesn't exists. Terminating..."
  exit 1
else
  echo "Rootfs source path (${ROOTFS_SOURCE_PATH}) contents: $(ls -alh "${ROOTFS_SOURCE_PATH}")"
fi

destination_directory_name="${workspace_directory}/dist"
echo "Ensuring that there are no leftovers in ${destination_directory_name}..."
rm -rf "${destination_directory_name}" || true
mkdir -p "${destination_directory_name}"

ROOTFS_ARCHIVE_FILE_PATH="${destination_directory_name}/$(basename "$ROOTFS_SOURCE_PATH")-${BRANCH_NAME:?}-${COMMIT_SHA:?}.tar.xz"
echo "Compressing ${ROOTFS_SOURCE_PATH} to ${ROOTFS_ARCHIVE_FILE_PATH}..."
XZ_OPT="-9 -T6" tar -cJf "${ROOTFS_ARCHIVE_FILE_PATH}" -C "${ROOTFS_SOURCE_PATH}" .

ROOTFS_CHECKSUM_FILE_PATH="${ROOTFS_ARCHIVE_FILE_PATH}.sha256sum"
echo "Calculating integrity hash of ${ROOTFS_ARCHIVE_FILE_PATH} and saving it to ${ROOTFS_CHECKSUM_FILE_PATH}..."
(
  cd "${ROOTFS_ARCHIVE_FILE_PATH%/*}"
  sha256sum "${ROOTFS_ARCHIVE_FILE_PATH##*/}" >"${ROOTFS_CHECKSUM_FILE_PATH}"
)

echo "Contents of the integrity hash file (${ROOTFS_CHECKSUM_FILE_PATH}): $(cat "${ROOTFS_CHECKSUM_FILE_PATH}")"
