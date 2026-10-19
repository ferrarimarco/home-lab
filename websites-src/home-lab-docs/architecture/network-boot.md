# Design Spec: Network Boot Service

## Implementation Status

| Component / Feature                   | Status      | Details                                                                     |
| :------------------------------------ | :---------- | :-------------------------------------------------------------------------- |
| **`netboot-server` Nix role on hl02** | **Missing** | Payload trees, per-host registry, and the rescue toggle.                    |
| **Server address reservation**        | **Missing** | hl02 has no DHCP reservation; the Raspberry Pi path needs a stable address. |
| **Raspberry Pi boot path**            | **Missing** | raspberrypi2 still boots SD then USB (`0xf41`) with no TFTP server address. |
| **x86 PXE boot path**                 | **Missing** | Deferred; design direction recorded, nothing verified.                      |
| **Raspberry Pi OS Lite payload**      | **Missing** | Pinned image unpacked on hl02, served over TFTP and NFS.                    |
| **Flash workflow**                    | **Missing** | The `flash-os` script delivered to the rescue system through cloud-init.    |
| **Raspberry Pi re-provisioning**      | **Missing** | Restore path, Trixie playbook fixes, and guides, tracked in the todo list.  |

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

A second server instance on pve2 would cover pve1 and hl02 once pve2 runs 24/7
and the PXE path exists; it is tracked in the todo list.

## Architecture Overview

1. **Boot server on hl02** (`netboot-server` Nix role): the services of each
   boot path, the payload trees, and a per-host registry.
2. **Rescue toggle**: a templated systemd unit per host, stopped by default.
   Starting it publishes the host's payload; stopping it withdraws it. The
   published state lives under a runtime path, so after a server reboot every
   host is in normal boot.
3. **Boot paths**: how a host of a given platform finds the server and what it
   fetches. Raspberry Pi over TFTP now, x86 PXE deferred.
4. **Payloads**: what a host runs once it network-boots. Raspberry Pi OS Lite
   over NFS now; later candidates recorded in the todo list.
5. **Consumers**: the workflows built on a rescue boot. Raspberry Pi
   re-provisioning now.

## Boot Server Role

The `netboot-server` role under `config/nix/roles/` takes an attribute set of
hosts, each naming its boot path and payload, and manages the trees under
`/var/lib/netboot/`:

- **TFTP root** (`tftp/`): one directory per host. The directory the host asks
  for is a link under a runtime path that the toggle manages, pointing at the
  payload's files.
- **NFS exports** (`nfs/<hostname>`): a writable per-host copy of a payload's
  root filesystem, exported to the lab network only, root squashing disabled
  because it is a root filesystem. It exists only while a rescue is active: the
  toggle creates it from the pristine tree when it starts and removes it after
  it stops.
- **HTTP root** (`http/`): per-host cloud-init seeds, installed-system
  cloud-init files, and the pinned images with their checksums.
- **The toggle**: `netboot-rescue@<hostname>`. Starting it cancels any pending
  removal, creates the host's export from the pristine tree, and publishes the
  TFTP link. Stopping it withdraws the link at once and removes the export after
  a grace period, because the workflow stops the toggle while the host still
  runs from that export and reboots afterwards: an immediate removal would pull
  the root filesystem from under a live system. A tmpfiles age rule on the
  export directory is the backstop for an hl02 reboot during the grace period.

On a normal boot a host asks for its directory, gets "not found", and continues
to its disk. With the toggle started, the host boots the payload on its next
reboot or power cycle, and keeps doing so until the toggle is stopped, which is
the last step of every rescue.

The firewall admits TFTP (UDP 69), NFSv4 (TCP 2049), and HTTP (TCP 80) from the
lab network only. The trees contain no secrets: firmware, public images, and
cloud-init files holding a hostname and a public key.

**Prerequisite: a DHCP reservation for hl02**, recorded in the inventory like
the other reserved addresses, because the Raspberry Pi path names the server by
address.

## Boot Paths

### Raspberry Pi

The Raspberry Pi 4 bootloader fetches firmware, kernel, and ramdisk over TFTP
from a server named in its EEPROM, so the router keeps its DHCP role. The
configuration is applied once from the running operating system with the
vendor's EEPROM tooling, which also installs the bootloader release bundled in
its package (accepted: the host keeps self-update enabled). It never changes
afterwards.

Bootloader releases are not this service's job: they come from the operating
system's `rpi-eeprom` package and the boot-time update service, which applies
the package's default channel while preserving the EEPROM configuration. Debian
11 froze that package at the January 2023 release, which is why raspberrypi2
reports no update available although upstream is at 2026-09-23; the re-image to
Trixie brings a current package and the update with it. Network boot needs no
newer release than the one installed.

| Option            | Value          | Reason                                                                |
| :---------------- | :------------- | :-------------------------------------------------------------------- |
| `BOOT_ORDER`      | `0xf42`        | Network first, then the boot disk, loop.                              |
| `TFTP_IP`         | hl02's address | Names the server, so the router's DHCP configuration stays untouched. |
| `TFTP_PREFIX`     | `1`            | Use a fixed per-host directory name.                                  |
| `TFTP_PREFIX_STR` | `<hostname>/`  | Per-host directory, no serial numbers in the repository.              |

### x86 PXE (deferred)

An x86 firmware finds the boot server through DHCP, which the router owns. The
design direction is a proxy-DHCP responder on hl02 that answers only the PXE
part of the exchange, leaving leases to the router; the pinned nixpkgs ships a
service that combines proxy DHCP, TFTP, and HTTP for PXE in one daemon, the
candidate to verify when this path is implemented. The toggle semantics are the
same: the responder answers only hosts whose toggle is started.

## Payloads

### Raspberry Pi OS Lite over NFS

The pinned Lite image, fetched by URL and checksum, is unpacked at build time (a
Nix derivation): its boot partition files go to the host's TFTP directory, its
root filesystem tree is the pristine copy of the host's NFS export. One pinned
image serves both as the rescue system and as the image the flash workflow
installs.

The role renders `config.txt` (64-bit mode, the Lite kernel and initramfs,
serial console) and a `cmdline.txt` that replaces the image's own: NFS root on
the host's export over NFSv4, DHCP addressing, the cloud-init seed URL, and none
of the image's first-boot resize hooks. The image's own cloud-init applies the
seed at boot: hostname, the `pi` user with the lab's bootstrap key and
passwordless sudo, password login disabled, and the `flash-os` script as a
written file. The tooling the rescue needs ships with Lite: EEPROM utilities,
`xz`, partition tools, `curl`, SMART tools.

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

## Testing

- The `netboot-server` role gets a NixOS integration test through the existing
  test generator: for a sample host, the TFTP service serves the payload files,
  the NFS export and the HTTP seed are reachable, and starting and stopping the
  toggle publishes and withdraws the host and resets the export.
- Payloads cannot boot in the x86_64 test framework. The dry rescue is the
  acceptance test, on real hardware with the boot disk untouched; it also
  verifies the two expectations below.

## Assumptions and Constraints

- Wired Ethernet, and for the Raspberry Pi hosts a bootloader release of 2023 or
  later (raspberrypi2 runs the January 2023 release).
- The EEPROM configuration is applied from a running operating system; a host
  with a lost configuration falls back to the SD card recovery path in the
  provisioning guide.
- When pve1 is down, raspberrypi2 is the monitoring replica still watching, and
  its own rescue waits for pve1 (see the coverage section).
- Two expectations verified by the dry rescue: the Lite kernel and initramfs
  boot from an NFS root, the layout the vendor's own network boot tutorial uses;
  and the image's cloud-init accepts a seed URL from the kernel command line.
  The installed system's first boot uses the same cloud-init mechanism,
  introduced by the Trixie release for headless setup.
- hl02 holds each pinned image plus an unpacked root tree per host, a few
  gigabytes on its 20 GB disk; image pins are bumped like other pinned
  artifacts.
