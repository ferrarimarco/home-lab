#!/usr/bin/env sh

set -e

echo "This script has been invoked with: $0 $*"

if ! TEMP="$(getopt -o fr: --long flasher,rootfs-archive-name: \
  -n 'build' -- "$@")"; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

rootfs_archive_name="rootfs.tar.xz"
flasher=

while true; do
  echo "Decoding parameter ${1}..."
  case "${1}" in
  -f | --flasher)
    flasher="enabled"
    shift
    ;;
  -r | --rootfs-archive-name)
    rootfs_archive_name="${2}"
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

rootfs_archive_integrity_checksum_path="${rootfs_archive_name}.sha256sum"

echo "Rootfs archive to use: ${rootfs_archive_name}"
if [ ! -f "${rootfs_archive_name}" ]; then
  echo "${rootfs_archive_name} archive doesn't exists. Terminating..."
  exit 1
fi

echo "Rootfs archive integrity file check to use: ${rootfs_archive_integrity_checksum_path}"
if [ ! -f "${rootfs_archive_integrity_checksum_path}" ]; then
  echo "${rootfs_archive_integrity_checksum_path} archive integrity checksum file doesn't exists. Terminating..."
  exit 1
fi

destination_directory_name="$(basename "${rootfs_archive_name}" .tar.xz)"
beaglebone_black_name="beaglebone-black-${destination_directory_name:?}"
options=

if [ "$flasher" = "enabled" ]; then
  beaglebone_black_name="${beaglebone_black_name}-eMMC-flasher"
  options="--emmc-flasher"
fi

image_size_suffix="2gb"
dtb="beaglebone"
am335x_v54ti="--dtb ${dtb} --rootfs_label rootfs --hostname beaglebone --enable-cape-universal --enable-uboot-pru-rproc-54ti"
options="--img-${image_size_suffix} ${beaglebone_black_name} ${options} ${am335x_v54ti}"

beaglebone_black_image_file_basename="${beaglebone_black_name}-${image_size_suffix}"
beaglebone_black_image_file_name="${beaglebone_black_image_file_basename}.img"
beaglebone_black_bitmap_file_name="${beaglebone_black_image_file_basename}.bmap"
beaglebone_black_archive_file_name="${beaglebone_black_image_file_name}.xz"
beaglebone_black_archive_integrity_check_file_name="${beaglebone_black_archive_file_name}.sha256sum"

workspace_directory="$(pwd)"
destination_directory_path="${workspace_directory}/${destination_directory_name}"

echo "Removing leftovers (${destination_directory_path})"
rm -rf "${destination_directory_path}"

echo "Verifying the integrity of ${rootfs_archive_name}..."
sha256sum -c --ignore-missing --strict "${rootfs_archive_integrity_checksum_path}"

echo "Extracting ${rootfs_archive_name} to ${destination_directory_path}..."
mkdir -p "${destination_directory_path}"
XZ_OPT="-T0" tar xf "${rootfs_archive_name}" -C "${destination_directory_path}"

PROJECT_FILE_PATH="${destination_directory_path}/image-builder.project"
echo "Sourcing ${PROJECT_FILE_PATH}..."
if [ ! -f "${PROJECT_FILE_PATH}" ]; then
  echo "${PROJECT_FILE_PATH} doesn't exists. Terminating..."
  exit 1
else
  echo "Contents of the project file: $(
    echo
    cat "${PROJECT_FILE_PATH}"
  )"
  # shellcheck source=/dev/null
  . "${PROJECT_FILE_PATH}"
fi

DTB_FILE_PATH="${destination_directory_path}/hwpack/${dtb}.conf"
echo "Checking if ${DTB_FILE_PATH} exists..."
if [ ! -f "${DTB_FILE_PATH}" ]; then
  echo "${DTB_FILE_PATH} doesn't exists. Terminating..."
  exit 1
else
  echo "Contents of the selected DTB configuration file (${DTB_FILE_PATH}): $(
    echo
    cat "${DTB_FILE_PATH}"
  )"
fi

rootfs_contents_archive_name="${deb_arch:?}-rootfs-${deb_distribution:?}-${deb_codename:?}.tar"
echo "Rootfs contents archive to use (was inside ${rootfs_archive_name}): ${rootfs_contents_archive_name}"

rootfs_contents_archive_path="${destination_directory_path}/${rootfs_contents_archive_name}"
echo "Rootfs contents archive path: ${rootfs_contents_archive_path}"

echo "${destination_directory_path} contents: $(ls -alh "${destination_directory_path}")"

rootfs_contents_destination_directory_name="$(basename "${rootfs_contents_archive_name}" .tar)"
rootfs_contents_destination_directory_path="${destination_directory_path}/${rootfs_contents_destination_directory_name}"
mkdir -p "${rootfs_contents_destination_directory_path}"
XZ_OPT="-T0" tar xf "${rootfs_contents_archive_path}" -C "${rootfs_contents_destination_directory_path}"

echo "${rootfs_contents_destination_directory_path} contents: $(ls -alh "${rootfs_contents_destination_directory_path}")"

configuration_directory_path="${workspace_directory}/configuration"
echo "Copying configuration files from ${configuration_directory_path} to ${rootfs_contents_destination_directory_path}..."
cp -Rv "${configuration_directory_path}"/. "${rootfs_contents_destination_directory_path}"/

echo "Removing old rootfs contents archive file (${rootfs_contents_archive_path})..."
rm -f "${rootfs_contents_archive_path}"

echo "Creating the new rootfs contents archive file (${rootfs_contents_archive_path})..."
tar -cf "${rootfs_contents_archive_path}" -C "${rootfs_contents_destination_directory_path}" .

echo "Removing rootfs contents directory (${rootfs_contents_destination_directory_path})..."
rm -rf "${rootfs_contents_destination_directory_path}"

echo "${destination_directory_path} contents: $(ls -alh "${destination_directory_path}")"

cd "${destination_directory_path}"
echo "Running setup_sdcard.sh ${options}..."
bash -e -c "$(pwd)/setup_sdcard.sh ${options}"
echo "$(pwd) contents: $(ls -alh)"

beaglebone_black_bitmap_file_path="${destination_directory_path}/${beaglebone_black_bitmap_file_name}"
beaglebone_black_image_file_path="${destination_directory_path}/${beaglebone_black_image_file_name}"
echo "Creating bitmap file: ${beaglebone_black_image_file_path}..."
bmaptool create -o "${beaglebone_black_bitmap_file_path}" "${beaglebone_black_image_file_path}"

echo "Compressing ${beaglebone_black_image_file_name}..."
xz -z -9 -T6 -v "${beaglebone_black_image_file_name}"

beaglebone_black_archive_integrity_check_file_path="${destination_directory_path}/${beaglebone_black_archive_integrity_check_file_name}"
echo "Creating ${beaglebone_black_archive_integrity_check_file_path} integrity checksum file..."
sha256sum "${beaglebone_black_archive_file_name}" >"${beaglebone_black_archive_integrity_check_file_path}"

build_destination_dir="${workspace_directory}/dist"
echo "Moving build artifacts to ${build_destination_dir}..."
mkdir -p "${build_destination_dir}"
mv "${beaglebone_black_bitmap_file_path}" "${build_destination_dir}/"
beaglebone_black_archive_file_path="${destination_directory_path}/${beaglebone_black_archive_file_name}"
mv "${beaglebone_black_archive_file_path}" "${build_destination_dir}/"
mv "${beaglebone_black_archive_integrity_check_file_path}" "${build_destination_dir}/"
echo "${build_destination_dir} contents: $(ls -alh "${build_destination_dir}")"

cd "${workspace_directory}"
