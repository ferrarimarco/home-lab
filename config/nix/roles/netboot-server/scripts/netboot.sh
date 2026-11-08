#!/usr/bin/env bash
# The steps the payload units and the rescue toggles run. The trees come from
# the environment (NETBOOT_*_DIR), and every name is validated before it is
# joined to a tree that gets removed. The role wraps this file with
# writeShellApplication, which prepends its own interpreter, options, and
# environment; the two lines below keep the file a complete script on its own.
#
#   netboot fetch PAYLOAD URL SHA256
#   netboot prepare HOST PAYLOAD SEED_DIR
#   netboot cancel-removal HOST
#   netboot export HOST CLIENTS
#   netboot publish HOST BOOT_FILES_DIR BOOT_CONFIG_DIR
#   netboot withdraw HOST
#   netboot remove-export HOST
set -o errexit
set -o nounset
set -o pipefail

check_names() {
  local name
  for name in "$@"; do
    if ! [[ $name =~ ^[a-z0-9-]+$ ]]; then
      echo "invalid name: $name" >&2
      exit 1
    fi
  done
}

# Fetch a pinned disk image and unpack it into the payload's pristine trees:
# the boot partition under boot/, the root filesystem under root/. Runs as
# root at runtime rather than in a derivation because a root filesystem needs
# its ownership, setuid bits, and sticky bits, which the Nix store strips.
fetch() {
  local name="$1" url="$2" sha256="$3"
  check_names "$name"
  local image="${NETBOOT_IMAGES_DIR:?}/$name.img.xz"
  local pin_file="$NETBOOT_IMAGES_DIR/$name.pin"
  local pin="$url $sha256"
  local payload_dir="${NETBOOT_PAYLOADS_DIR:?}/$name"

  if [[ -f $pin_file && "$(<"$pin_file")" == "$pin" && -d $payload_dir/boot && -d $payload_dir/root ]]; then
    echo "payload $name is ready"
    return 0
  fi
  rm -f "$pin_file"

  if ! [[ -f $image ]] || ! echo "$sha256  $image" | sha256sum --check --status; then
    echo "downloading $url"
    curl --fail --location --silent --show-error --output "$image.part" "$url"
    echo "$sha256  $image.part" | sha256sum --check --status
    mv "$image.part" "$image"
  fi

  # The trap's variables stay global: an EXIT trap set in a function runs
  # without its locals on a normal return and on an errexit failure alike.
  raw="$NETBOOT_IMAGES_DIR/$name.img"
  work="${NETBOOT_PAYLOADS_DIR:?}/$name.unpacking"
  mounts="${NETBOOT_RUN_DIR:?}/mnt/$name"
  loops=()
  cleanup() {
    umount "$mounts/boot" 2>/dev/null || true
    umount "$mounts/root" 2>/dev/null || true
    local device
    for device in "${loops[@]}"; do
      losetup --detach "$device" || true
    done
    rm -f "$raw"
    rm -rf "$work"
  }
  trap cleanup EXIT

  rm -rf "$work"
  mkdir -p "$work/boot" "$work/root" "$mounts/boot" "$mounts/root"
  echo "unpacking $image"
  xz --decompress --stdout "$image" >"$raw"
  # One loop device per partition, at the offsets the partition table gives,
  # rather than a scanned device whose partition nodes udev creates and then
  # recreates on its own rescan: a mount in that window fails even when the
  # node exists.
  local number geometry start sectors
  for number in 1 2; do
    geometry=$(partx --show --noheadings --output START,SECTORS --nr "$number" "$raw")
    [[ -n $geometry ]] || {
      echo "no partition $number in $image" >&2
      exit 1
    }
    read -r start sectors <<<"$geometry"
    loops+=("$(losetup --find --show --read-only --offset $((start * 512)) --sizelimit $((sectors * 512)) "$raw")")
  done
  mount -o ro "${loops[0]}" "$mounts/boot"
  mount -o ro "${loops[1]}" "$mounts/root"
  cp -a "$mounts/boot/." "$work/boot/"
  cp -a "$mounts/root/." "$work/root/"
  umount "$mounts/boot"
  umount "$mounts/root"
  losetup --detach "${loops[@]}"
  loops=()
  rm -f "$raw"

  rm -rf "$payload_dir"
  mv "$work" "$payload_dir"
  echo "$pin" >"$pin_file"
  cleanup
  trap - EXIT
  echo "payload $name is ready"
}

# Create a host's NFS export as a fresh copy of a payload's pristine root.
prepare() {
  local host="$1" payload="$2" seed_dir="$3"
  check_names "$host" "$payload"
  local pristine="$NETBOOT_PAYLOADS_DIR/$payload/root"
  if ! [[ -f $NETBOOT_IMAGES_DIR/$payload.pin && -d $pristine ]]; then
    echo "payload $payload is not ready: check netboot-payload-$payload.service" >&2
    exit 1
  fi
  local export_dir="${NETBOOT_NFS_DIR:?}/$host"
  rm -rf "$export_dir"
  mkdir "$export_dir"
  cp -a "$pristine/." "$export_dir/"
  # The image mounts its own partitions by PARTUUID; over NFS they do not
  # exist and systemd would drop to emergency mode waiting for them. The
  # vendor's network boot tutorial makes the same edit.
  printf 'proc /proc proc defaults 0 0\n' >"$export_dir/etc/fstab"
  # The image's cloud-init reads its seed from the boot partition, a setting
  # of the image that overrides a seed named on the kernel command line, so
  # the rendered seed takes the place of the vendor's files there.
  cp -rL "$seed_dir"/. "$export_dir/boot/firmware/"
  # The image grows its root partition at first boot; an NFS root has none.
  ln -sf /dev/null "$export_dir/etc/systemd/system/systemd-growfs-root.service"
  echo "prepared $export_dir from $pristine"
}

# Cancel a pending export removal: the timer, and the cleanup service if the
# timer already fired and the removal is in progress.
cancel_removal() {
  local host="$1"
  check_names "$host"
  local unit
  for unit in "netboot-export-cleanup-$host.timer" "netboot-export-cleanup-$host.service"; do
    if systemctl is-active --quiet "$unit"; then
      systemctl stop "$unit"
      echo "cancelled $unit"
    fi
  done
}

# Export a host's directory through its own file under /etc/exports.d, which
# the NFS server reads beside /etc/exports: the export list then shows the
# hosts in rescue only, and a server restart during a rescue keeps the export.
export_host() {
  local host="$1" clients="$2"
  check_names "$host"
  printf '%s %s(%s)\n' "$NETBOOT_NFS_DIR/$host" "$clients" "$NETBOOT_EXPORT_OPTIONS" >"/etc/exports.d/netboot-$host.exports"
  exportfs -r
  echo "exported $NETBOOT_NFS_DIR/$host to $clients"
}

# Publish a host's TFTP directory: the payload's boot files with the rendered
# boot configuration in place of the image's own and of its cloud-init seed.
publish() {
  local host="$1" boot_files="$2" boot_config="$3"
  check_names "$host"
  local target="${NETBOOT_TFTP_DIR:?}/$host"
  rm -rf "$target"
  mkdir -p "$target"
  cp -r "$boot_files/." "$target/"
  rm -f "$target/config.txt" "$target/cmdline.txt" "$target/user-data" "$target/meta-data" "$target/network-config"
  cp "$boot_config/config.txt" "$boot_config/cmdline.txt" "$target/"
  echo "published $target"
}

withdraw() {
  local host="$1"
  check_names "$host"
  rm -rf "${NETBOOT_TFTP_DIR:?}/$host"
  echo "withdrawn $NETBOOT_TFTP_DIR/$host"
}

remove_export() {
  local host="$1"
  check_names "$host"
  rm -f "/etc/exports.d/netboot-$host.exports"
  exportfs -r
  rm -rf "${NETBOOT_NFS_DIR:?}/$host"
  echo "removed $NETBOOT_NFS_DIR/$host"
}

command="${1:-}"
shift || true
case "$command" in
fetch) fetch "$@" ;;
prepare) prepare "$@" ;;
cancel-removal) cancel_removal "$@" ;;
export) export_host "$@" ;;
publish) publish "$@" ;;
withdraw) withdraw "$@" ;;
remove-export) remove_export "$@" ;;
*)
  echo "usage: netboot fetch|prepare|cancel-removal|export|publish|withdraw|remove-export ..." >&2
  exit 1
  ;;
esac
