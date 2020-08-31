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
am335x_v54ti="--dtb beaglebone --rootfs_label rootfs --hostname beaglebone --enable-cape-universal --enable-uboot-pru-rproc-54ti"
options="--img-${image_size_suffix} ${beaglebone_black_name} ${options} ${am335x_v54ti}"

beaglebone_black_image_file_basename="${beaglebone_black_name}-${image_size_suffix}"
beaglebone_black_image_file_name="${beaglebone_black_image_file_basename}.img"
beaglebone_black_bitmap_file_name="${beaglebone_black_image_file_basename}.bmap"
beaglebone_black_archive_file_name="${beaglebone_black_image_file_name}.xz"
beaglebone_black_archive_integrity_check_file_name="${beaglebone_black_archive_file_name}.sha256sum"

echo "Removing leftovers (${destination_directory_name})"
rm -rf "${destination_directory_name}"

echo "Verifying the integrity of ${rootfs_archive_name}..."
sha256sum -c --ignore-missing --strict "${rootfs_archive_integrity_checksum_path}"

workspace_directory="$(pwd)"

echo "Extracting ${rootfs_archive_name} to ${destination_directory_name}..."
mkdir -p "${destination_directory_name}"
XZ_OPT="-T0" tar xf "${rootfs_archive_name}" -C "${destination_directory_name}"

echo "Running setup_sdcard.sh ${options}..."
cd "${destination_directory_name}"
echo "$(pwd) contents: $(ls -alh)"
bash -c "$(pwd)/setup_sdcard.sh ${options}"

echo "$(pwd) contents: $(ls -alh)"
echo "Creating bitmap file: ${beaglebone_black_image_file_name}..."
bmaptool create -o "${beaglebone_black_bitmap_file_name}" "${beaglebone_black_image_file_name}"

echo "Compressing ${beaglebone_black_image_file_name}..."
xz -z -9 -T6 -v "${beaglebone_black_image_file_name}"

echo "Creating ${beaglebone_black_archive_integrity_check_file_name} integrity checksum file..."
sha256sum "${beaglebone_black_archive_file_name}" >"${beaglebone_black_archive_integrity_check_file_name}"

build_destination_dir="${workspace_directory}/dist"
echo "Moving build artifacts to ${build_destination_dir}"
mkdir -p "${build_destination_dir}"
mv "${beaglebone_black_bitmap_file_name}" "${build_destination_dir}/"
mv "${beaglebone_black_archive_file_name}" "${build_destination_dir}/"
mv "${beaglebone_black_archive_integrity_check_file_name}" "${build_destination_dir}/"
echo "${build_destination_dir} contents: $(ls -alh "${build_destination_dir}")"

cd "${workspace_directory}"
