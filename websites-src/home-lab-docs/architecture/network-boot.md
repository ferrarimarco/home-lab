# Design Spec: Network Boot Service

## Implementation Status

| Component / Feature                   | Status                    | Details                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| :------------------------------------ | :------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`netboot-server` Nix role on hl02** | **Fully Implemented**     | Trees, per-host toggle, proxy DHCP and TFTP (dnsmasq), NFSv3 exports with the rescue seed on the export's boot directory, HTTP images and installed seeds, firewall; the hl02 integration test passes; applied on hl02 on 2026-11-05 and exercised by the dry rescue of 2026-11-07; the seed placement fix of that day applied on 2026-11-07, and the old `seeds/` directory under the HTTP root, which tmpfiles does not clean up for a dropped rule, removed by hand on 2026-11-08.                                |
| **Server address reservation**        | **Fully Implemented**     | hl02 is reserved at `10.0.0.5` on the gateway, rendered from the inventory by the `gateway-dnsmasq` playbook (applied and verified 2026-10-28; no CI test covers the playbook).                                                                                                                                                                                                                                                                                                                                      |
| **Raspberry Pi boot path**            | **Fully Implemented**     | Proxy DHCP answer, per-host TFTP directory, rendered boot configuration, covered by the test; the EEPROM configuration declared in the inventory, asserted by the node role (no CI test covers the assertion, the Molecule instance not being a Raspberry Pi), applied on raspberrypi2 on 2026-11-07 and verified by the dry rescue: network boot with the toggle started, fall-through to the SSD within 20 seconds with it stopped, on warm reboots and cold starts.                                               |
| **x86 PXE boot path**                 | **Missing**               | Deferred; the responder it needs exists, its `pxe-service` entry, boot file, and payload type do not.                                                                                                                                                                                                                                                                                                                                                                                                                |
| **Raspberry Pi OS Lite payload**      | **Fully Implemented**     | The 2026-10-06 Trixie release pinned, fetched and unpacked at runtime, per-host export with the fstab rewritten, the seed on its boot directory and the root-growing unit masked; booted by raspberrypi2 in the dry rescue of 2026-11-07 (NFS root, SSD visible and untouched; the seed was applied once placed on the export's boot directory by hand, which the fix of that day codifies); the test covers the path with a mock image, not the boot.                                                               |
| **Flash workflow**                    | **Partially Implemented** | `flash-os` delivered through the rescue seed and present on the rescue system of 2026-11-07, where its argument check was exercised; never run against a disk.                                                                                                                                                                                                                                                                                                                                                       |
| **Raspberry Pi re-provisioning**      | **Partially Implemented** | The node role's Raspberry Pi OS specifics target Trixie since 2026-11-08; a check run of the untagged tasks against the rescue system failed nothing and computed the package list (apt did not validate it), the fail2ban jail and the package operations not yet; until the re-image the Bullseye host takes tag-scoped runs without the `install-debian-packages` and `fail2ban` tags; the restore order is in the backup operations guide; the flash and the first real run on the new system have not happened. |
| **Monitoring**                        | **Fully Implemented**     | Unit states through the node exporter's systemd collector, the lingering-rescue rule, and the HTTP and NFS probes; the rule tests and the hl02 check pass; applied on 2026-11-06; the rule rewritten on 2026-11-07 after it fired falsely for a stopped toggle, applied on both replicas the same day and seen clearing the false alert.                                                                                                                                                                             |

## Goal

One boot server on hl02 that can network-boot any lab host on demand, for rescue
or for re-provisioning, with normal boot from the host's own disk as the
default. A host network-boots only while its toggle on the server is started, so
a host whose operating system is dead is rescued from hl02 without a physical
visit, and re-provisioning needs no flashing station.

The first consumer is raspberrypi2, whose Debian 11 installation is past end of
life and which the archived
[stability notes](../archive/raspberrypi2-stability-issues.md) recommend
re-imaging rather than upgrading in place. The target is the Lite (no desktop)
64-bit release of Raspberry Pi OS. The Proxmox nodes are the next candidates,
through a PXE path that is designed for but deferred.

## Rationale

The decision whether a host boots from the network or from its disk belongs on
the server, not in the host: a host-side switch (a boot order flipped from the
running system, a fallback that triggers only on firmware-level failures) needs
the host to be alive or the failure to be of the right kind. With the network
first in every host's boot order and the server answering "not found" by
default, the toggle covers every failure the host can have, at the cost of a few
seconds per normal boot.

The payloads are vendor or lab images served as they are and customized at boot,
reset before every use, so nothing is maintained by hand and nothing has to be
built for a foreign architecture.

### Rejected alternatives

- **Boot disk first with the network as fallback.** The fallback triggers only
  when the bootloader finds no bootable firmware. The failure raspberrypi2
  actually has, a root filesystem stall after the firmware stage, would not fall
  through. Rejected on 2026-10-08.
- **A NixOS netboot payload for the Raspberry Pi hosts.** An aarch64 artifact in
  a lab whose builders are x86_64: it needs a remote builder (the host being
  rescued) or emulation, plus a release pipeline, because hl02 builds its own
  configuration through comin on two cores. Rejected on 2026-10-08.
- **Resident rescue SD card.** Written by hand, ages outside version control,
  and the first insertion needs the host's case opened. Kept only as the
  recovery path for a host whose EEPROM configuration is lost.
- **A server address in the Raspberry Pi EEPROM (`TFTP_IP`).** The bootloader
  can take the TFTP server from its EEPROM instead of from DHCP, which leaves no
  DHCP footprint on the LAN. It bakes the server's address into every client, to
  be edited from a running system on each Pi if it ever changes, and the x86
  path needs a proxy DHCP responder anyway. Rejected on 2026-11-05 for the
  proxy, which the vendor's own network boot tutorial uses.
- **HTTP boot for the Raspberry Pi hosts.** Requires the boot image to be signed
  with a key stored in the EEPROM, which a public bootloader update erases;
  raspberrypi2 keeps bootloader self-update enabled.
- **Bootloader network install**: needs a display and a keyboard.
- **Reinstall from the running system** (RAM root or `kexec`): no rescue path if
  the write fails midway.

## Coverage

The service rescues a host only while the server runs, so it cannot cover its
own failure domain:

- **Covered:** the Raspberry Pi hosts; later, through the PXE path, any physical
  node other than the one hosting the server.
- **Not covered:** pve1, the node that hosts hl02; hl02 itself; and any host
  whose rescue would happen while pve1 is down. For those the recovery path
  stays the one of the [bootstrapping spec](./home-lab-bootstrapping.md): the
  installer artifacts and the SD card path of the provisioning guide.
- **Out of scope:** Proxmox guests. Terraform re-creates them from the installer
  artifacts, so they never need a rescue boot.

The server is a VM on pve1, so a rescue of raspberrypi2 waits for pve1 when both
are down at once. A normal boot of a Raspberry Pi host while the server is down
still succeeds: the bootloader tries the network first, finds no "Raspberry Pi
Boot" reply, and moves to its disk after its DHCP timeout. With the server up,
that attempt ends in a second or two with "not found".

A second server instance on pve2 would cover pve1 and hl02 once pve2 runs 24/7
and the PXE path exists; it is tracked in the todo list, with the constraint
that two responders must not both answer: the bootloader takes the first reply
and gives up when that server has no directory for the host.

## Architecture Overview

1. **Boot server on hl02** (`netboot-server` Nix role): the shared responder and
   TFTP tree, the payload trees, a per-host registry, and one file per platform
   and per payload type.
2. **Rescue toggle**: a systemd unit per host, stopped by default. Starting it
   publishes the host's payload; stopping it withdraws it. The published state
   lives under a runtime path, so after a server reboot every host is in normal
   boot.
3. **Boot paths**: how a host of a given platform finds the server and what it
   fetches. Raspberry Pi over TFTP now, x86 PXE deferred.
4. **Payloads**: what a host runs once it network-boots. Raspberry Pi OS Lite
   over NFS now; later candidates recorded in the todo list.
5. **Consumers**: the workflows built on a rescue boot. Raspberry Pi
   re-provisioning now.

## Boot Server Role

The `netboot-server` role under `config/nix/roles/` takes an attribute set of
hosts, each naming its platform (boot path) and its payload, plus the server's
address, the lab interface, and the client network. Platforms and payload types
are files under the role's `platforms/` and `payloads/` directories, registered
under their filenames: a platform provides how a host's boot files are published
and which boot configuration it renders; a payload type provides how its image
is fetched and unpacked, how a host's copy is prepared, and the kernel
parameters that boot it. Adding an operating system shape or a boot path adds a
file. The core composes them and manages:

- **Payload trees** (`/var/lib/netboot/payloads/<payload>/`): the image's boot
  partition under `boot/` and its root filesystem under `root/`, pristine. A
  unit per payload downloads the image into `images/` by URL, verifies its
  SHA-256, and unpacks it at runtime as root through a loop mount: the Nix store
  strips ownership, setuid, and sticky bits, so a root filesystem cannot be a
  derivation output. The unit records the pin it unpacked and does nothing while
  the pin is unchanged. It is a long-running service rather than a oneshot, so a
  deployment never waits for the download; the toggle checks the recorded pin
  instead of the unit's state. A failed fetch leaves the unit failed, with no
  automatic restart, so the unit alert reports it; restart the unit once the
  cause is fixed.
- **TFTP root** (`/run/netboot/tftp/<hostname>/`): a copy of the payload's boot
  files with the rendered boot configuration in place of the image's own and of
  its cloud-init seed. Under the runtime tree, so a server reboot withdraws
  every host.
- **NFS exports** (`/var/lib/netboot/nfs/<hostname>/`): a writable per-host copy
  of the payload's root filesystem with its fstab reduced to `proc` (the image
  mounts its own partitions by PARTUUID, which do not exist over NFS; the
  vendor's tutorial makes the same edit), the rendered cloud-init seed in place
  of the vendor's files on its boot directory (`boot/firmware/`, where the
  image's own cloud-init configuration reads the seed from, a setting that
  overrides a seed URL on the kernel command line), and the image's root-growing
  unit masked, exported to the client network with root squashing disabled
  because it is a root filesystem. It exists only while a rescue is active, and
  so does its export: the toggle writes a per-host file under `/etc/exports.d/`,
  which the NFS server reads beside its empty `/etc/exports`, so the export list
  shows the hosts in rescue only and a server restart during a rescue keeps the
  export.
- **HTTP root** (`/var/lib/netboot/http/`): the installed-system seeds
  (`installed/<hostname>/`) and the images with their checksums (`images/`),
  what the flash script fetches.
- **The toggle**: `netboot-rescue@<hostname>`, a fully specified unit per host.
  Starting it cancels any pending removal, creates the host's export from the
  pristine tree, exports it, and publishes the TFTP directory. Stopping it
  withdraws the directory at once and schedules the export's removal after a
  grace period (ten minutes by default) through a transient timer, because the
  workflow stops the toggle while the host still runs from that export and
  reboots afterwards: an immediate removal would pull the root filesystem from
  under a live system. The toggle only wants its daemons and is left alone by
  deployments, so a rescue in progress survives a daemon restart and a change to
  the role. A boot-only tmpfiles rule removes the exports and their files on an
  hl02 reboot, rather than an age rule, which would let the daily cleaner delete
  the untouched files of a live export.
- **The daemons**: dnsmasq as the proxy DHCP responder (see the boot paths) and
  the TFTP server on the runtime tree, with DNS disabled; the kernel NFS server,
  version 3 only, with a fixed mountd port; nginx on the HTTP root.

On a normal boot a host asks for its directory, gets "not found", and continues
to its disk. With the toggle started, the host boots the payload on its next
reboot or power cycle, and keeps doing so until the toggle is stopped, which is
the last step of every rescue. The
[network boot guide](../guides/operations/network-boot.md) has the commands and
the checks.

The firewall admits proxy DHCP (UDP 67 and 4011), TFTP (UDP 69), rpcbind (111),
NFS (TCP 2049) with mountd (20048), and HTTP (TCP 80) on the lab interface only.
The trees contain no secrets: firmware, public images, and cloud-init files
holding a hostname and a public key.

**Prerequisite: a DHCP reservation for hl02**, recorded in the inventory like
the other reserved addresses: the proxy DHCP reply and the rendered boot
configuration carry the address, and a rescue in progress depends on it staying
put. The flake cannot read the inventory, so the host configuration repeats the
address and the interface.

## Boot Paths

### Raspberry Pi

The Raspberry Pi 4 bootloader sends a PXE-class DHCP discover, takes its lease
from the router, and looks for a reply carrying the "Raspberry Pi Boot" vendor
option, whose server address is the TFTP server it fetches firmware, kernel, and
ramdisk from. hl02 answers that part of the exchange only (dnsmasq in proxy DHCP
mode, as the vendor's network boot tutorial does), so the router keeps its DHCP
role and no client stores the server's address (the EEPROM alternative is in the
rejected alternatives). The cost is a responder that answers every PXE-class
discover on the LAN: a PXE-booting x86 machine is offered the same entry, since
the bootloader announces the x86 BIOS architecture code, and then gets "not
found" from TFTP, the same fall-through the toggle relies on.

The EEPROM configuration is declared per host in the inventory
(`raspberry_pi_bootloader_configuration`), with the options below added to the
ones the host already carries. The node role renders it to a file on the host
and asserts that the live configuration matches, in the runs that name the
`raspberry-pi-bootloader` tag and in full runs: the EEPROM sits outside every
system the lab manages, and a configuration lost to a recovery flash or to a
bootloader update would otherwise close the rescue path without a sign. Until
the configuration is applied on a host, a full run fails for it at the end of
the node play and skips the later plays of `main.yaml`, the backup play
included; scoped runs of other stacks are unaffected. Applying it stays a manual
step with the vendor's tooling and a reboot, which the
[network boot guide](../guides/operations/network-boot.md) describes. The tool
patches a bootloader image and, without an explicit one, takes the newest image
of its own package, so the image of the installed release is passed: on
raspberrypi2 the Debian 11 package stops at the January 2023 image while the
EEPROM runs the 2026-09-23 release (read on 2026-11-06), and the default would
downgrade it.

Bootloader releases are not this service's job: they come from the operating
system's `rpi-eeprom` package and the boot-time update service, which applies
the package's default channel while preserving the EEPROM configuration. The
re-image to Trixie brings raspberrypi2 a package that matches its installed
release. Network boot needs no newer release than the one installed.

| Option            | Value         | Reason                                                         |
| :---------------- | :------------ | :------------------------------------------------------------- |
| `BOOT_ORDER`      | `0xf142`      | Network first, then the USB boot disk, then the SD card, loop. |
| `TFTP_PREFIX`     | `1`           | Use a fixed per-host directory name.                           |
| `TFTP_PREFIX_STR` | `<hostname>/` | Per-host directory, no serial numbers in the repository.       |

The bootloader's `DHCP_TIMEOUT` (45 seconds by default, 5 at least) bounds the
wait before a host moves to its disk when no server answers. It stays at the
default: with the server up, the whole network stage of raspberrypi2 (DHCP, the
eight TFTP requests answered "not found", the move to the disk) takes under ten
seconds, and the kernel's own DHCP follows 20 seconds after the attempt; the
timeout only matters while hl02 is down, when the router still answers the
discover at once and the bootloader waits for the vendor option that never
comes.

The dry rescue of 2026-11-07 measured the path on raspberrypi2: 19 seconds for
the toggle start on hl02 (the copy of the 1.9 GB root tree, the export, the boot
files), 72 seconds from power-on to the rescue system answering SSH, and 43
seconds from the reboot command on the rescue system to the installed system
answering SSH from its SSD. It also found that a USB device that fails its
cold-start enumeration (a Coral USB accelerator on a hub) hangs the bootloader
after the network stage and hangs the rescue kernel before the NFS mount, while
warm reboots work: the
[network boot guide](../guides/operations/network-boot.md) has the symptoms.

### x86 PXE (deferred)

An x86 firmware finds the boot server through DHCP, which the router owns. The
responder on hl02 is the one the Raspberry Pi path uses: the x86 path adds a
`pxe-service` entry for the x86 architecture naming a PXE boot file served from
the same TFTP tree, and a payload type for what it boots. Nothing of it is
verified. The toggle semantics are the same: a host without a published
directory gets "not found".

## Payloads

### Raspberry Pi OS Lite over NFS

The pinned Lite image (the 2026-10-06 Trixie release), fetched by URL and
SHA-256 and unpacked at runtime as the boot server role describes: its boot
partition files are the host's TFTP directory, its root filesystem tree is the
pristine copy of the host's NFS export. One pinned image serves both as the
rescue system and as the image the flash workflow installs.

The role renders `config.txt` (64-bit mode, the Lite kernel and its initramfs,
serial console) and a `cmdline.txt` that replaces the image's own: the NFS root
on the host's export over NFSv3 (TCP, no locking: what the image's initramfs
mounts the root with through the klibc `nfsmount`, which speaks versions 2 and
3; NFS and the Pi 4 Ethernet driver are built into the image's kernel), DHCP
addressing, and none of the image's first-boot resize hooks. The image's own
cloud-init applies the seed from the export's boot directory at boot: hostname,
the `pi` user with the lab's bootstrap key and passwordless sudo, password login
disabled, the network left as the kernel configured it, and the `flash-os`
script as a written file. The tooling the rescue needs ships with Lite: EEPROM
utilities, `xz`, partition tools, `curl` (no SMART tools; the flash workflow
needs none).

### Later candidates

The lab's own NixOS installer ISO for bare-metal nodes, and a generic rescue
menu, are recorded in the todo list without design.

## Consumer: Raspberry Pi Re-provisioning

**Flash workflow.** `flash-os` takes the image URL on hl02, its checksum, the
target disk by stable device ID, and the URL prefix of the installed system's
cloud-init files. It refuses to run without all four, or against a target that
is not a whole disk or has a mounted filesystem; prints the target's model and
size and waits for an explicit confirmation token; then downloads and verifies
the image, writes it, re-reads the partition table, writes the three cloud-init
files to the new boot partition, and reports. It does not reboot and does not
touch the EEPROM.

**Workflow.**

1. Preparation on the current system: workload images upgraded in place to the
   repository's pins, the playbook fixes for the target release merged and
   tested, the EEPROM configuration applied, hl02 serving the host.
2. A dry rescue: start the toggle, reboot, confirm SSH access to the rescue
   system and that it sees the boot disk and the data disks, stop the toggle,
   reboot. This is the only test the payload gets before a real flash.
3. Silence the host's availability alerts. Stop every workload stack, run the
   backup job once with its repository check, record the snapshot ID, confirm
   the exporter reports it.
4. Start the toggle, reboot into the rescue system, run `flash-os` with the
   confirmation token, stop the toggle, reboot into the new system.
5. Replace the host's entry in the control machine's known hosts, run the
   bootstrap playbook, then the node playbooks limited to the host with the
   workload start flags disabled: the data disks mount and every stack is
   rendered without starting.
6. Restore the recorded snapshot through the host's restic container into the
   two state trees, remove the start flags, run the playbooks again.
7. The manual steps below, then verify and expire the silence.

A rescue outside re-provisioning (a host that stopped booting) is step 4 without
the flash: start the toggle, power-cycle, investigate over SSH with the disks
attached, stop the toggle, reboot. The host's availability alert is what signals
the need; the rescue system never reboots on its own.

**State outside the snapshots.** The restic job snapshots
`/etc/ferrarimarco-home-lab` and `/var/lib/ferrarimarco-home-lab`. Everything
else comes back from the playbooks, except:

| State                       | Recovery                                                   |
| :-------------------------- | :--------------------------------------------------------- |
| Tailscale node identity     | Re-join, re-approve routes, delete the old node.           |
| Samba passwords             | Set by hand; the playbooks create users and shares only.   |
| SSH host keys               | Regenerated; replace the control machine's known hosts.    |
| Container images            | Re-pulled from the registries.                             |
| Hand-installed case tooling | Reinstall; the role only enables the I2C and serial buses. |

## Security Considerations

- The NFS exports are root filesystems, so root squashing is off. They are
  limited to the lab network, hold public images only, exist only during a
  rescue, and are created fresh for each one, so nothing written during a rescue
  persists or lingers.
- Flashing is never automatic: a rescue system boots into an idle shell, and the
  write needs an SSH session, a confirmation token, and a disk named by its
  stable ID.
- The boot firmware's trust is the LAN: a rogue server could serve a different
  system to a host whose toggle is started. The lab network is private and the
  toggle is started on demand; secure boot with signed payloads is out of scope.

## Monitoring

The alerts that cover the server (its units, the probes of its HTTP and NFS
endpoints, and the rule for a rescue left started) are described in the
[Monitoring Alerting specification](./monitoring-alerting.md), in its network
boot and Blackbox probe sections.

## Testing

- The `netboot-server` role has a NixOS integration test through the existing
  test generator, against a mock image of the same shape (an MBR image with a
  FAT boot partition and an ext4 root, built-in a derivation): the payload unit
  unpacks it; with the toggle stopped, TFTP answers "not found" and the export
  list is empty; starting the toggle serves the rendered command line and the
  boot files over TFTP (not the vendor seed), lists the export and mounts it
  over NFSv3 with the rewritten fstab and the rescue seed on its boot directory;
  stopping withdraws the TFTP directory at once, keeps the export, and removes
  it after the grace period. The proxy DHCP answer cannot be exercised without a
  PXE-class client; the test reads its presence from the dnsmasq log.
- Payloads cannot boot in the x86_64 test framework. The dry rescue is the
  acceptance test, on real hardware with the boot disk untouched; it also
  verifies the three expectations below.

## Assumptions and Constraints

- Wired Ethernet, and for the Raspberry Pi hosts a bootloader release of 2023 or
  later.
- The EEPROM configuration is applied from a running operating system; a host
  with a lost configuration falls back to the SD card recovery path in the
  provisioning guide.
- When pve1 is down, raspberrypi2 is the monitoring replica still watching, and
  its own rescue waits for pve1 (see the coverage section).
- Three expectations checked by the dry rescue: the Lite kernel and initramfs
  boot from an NFS root, the layout the vendor's own network boot tutorial uses
  (verified); NetworkManager leaves the interface the kernel configured alone,
  so the root stays mounted (verified); and the image's cloud-init accepts a
  seed URL from the kernel command line (disproved: the image's own
  configuration names the boot partition as the seed source and overrides the
  command line, so the seed goes on the export's boot directory). The installed
  system's first boot uses the same cloud-init mechanism, introduced by the
  Trixie release for headless setup.
- hl02 holds each pinned image, its unpacked trees, and a root copy per host in
  rescue, a few gigabytes on its 20 GB disk (about 6 GB at the peak of an
  unpack); image pins are bumped like other pinned artifacts.
