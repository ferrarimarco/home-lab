# Network boot server

This guide covers the boot server on hl02 that the
[Network Boot Service](../../architecture/network-boot.md) specification
describes: how to put a host in rescue and back, how to read the server's state,
how to re-image a Raspberry Pi through the rescue, and how to move the image
pin. The design, the trees, and the toggle semantics are in the specification;
this page holds the commands.

## Start and stop a rescue

A host network-boots only while its toggle on hl02 is started. Starting it
copies the payload's root tree into the host's export (19 seconds for the 1.9 GB
tree of Raspberry Pi OS Lite on hl02) and publishes the host's boot files:

```shell
sudo systemctl start netboot-rescue@raspberrypi2
```

The host boots the payload on its next reboot or power cycle, and keeps doing so
until the toggle is stopped. Stop it when the rescue is over, with the host
still running from the export, then reboot the host, which boots from its own
disk again:

```shell
sudo systemctl stop netboot-rescue@raspberrypi2
```

The stop withdraws the boot files at once and removes the export after the grace
period of the role's `exportRemovalDelay` option (ten minutes by default), so
the running host keeps its root until it reboots. A start within that period
cancels the removal but rebuilds the export from the pristine tree, so a host
still running from it must reboot anyway. A reboot of hl02 withdraws every host
and removes every export.

A toggle left started for 24 hours raises the `NetbootRescueLingering` alert:
stop it if the rescue is over, or silence the alert for a planned rescue that
runs longer, as the [monitoring operations guide](./monitoring.md) describes.

The toggle fails with `payload raspios-lite is not ready` when the payload unit
has not finished downloading and unpacking the image, which happens once per
pin; check the unit as the next section describes and start the toggle again
afterwards. A payload unit in the failed state does not retry on its own:
restart it once the cause (a download error, a checksum mismatch, a full disk)
is fixed.

### Check the playbooks against the rescue system

The rescue system is a stock image of the release the re-image installs, so a
playbook can be check-run against it before any disk is written. The hostname
and address are the installed system's, the `pi` user carries the bootstrap key,
and the host key differs from the installed system's, so the run disables the
host key check:

```shell
ADDITIONAL_ANSIBLE_FLAGS="--check --diff --tags untagged --tags fail2ban --tags install-debian-packages --tags uninstall-debian-packages --limit raspberrypi2.edge.lab.ferrari.how --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" \
  ANSIBLE_PLAYBOOK_FILE_NAME="home-lab-node.yaml" scripts/run-ansible.sh
```

Name the tags of the stacks whose values change beside `untagged`, and the two
package tags when package names change: a run without them never reaches the
stack's templates or the apt tasks, so it exercises neither the values nor the
package names, which the apt module validates in check mode. Read the run for
those, not for a clean prediction: the rescue system has none of the
prerequisites the earlier playbooks install, so a task that depends on them may
fail or predict a first deployment. The cloud-init of the rescue is still
running in the first minutes after boot, and the toggle, the reboots and the
silences are the ones of the rescue procedure above.

### A host that does not come up

Connect a display: the Raspberry Pi bootloader shows a diagnostics screen whose
`boot:` line names the stage it is in (`mode NETWORK 2`, `mode USB-MSD 4`), the
boot order, and the retry and restart counts. With the toggle stopped, the
expected screen shows the DHCP answer, eight TFTP "not found" lines, and then
the USB stage; hl02's dnsmasq journal shows the same eight requests, and the
bootloader's "f" restart would produce a new DHCP exchange there every 30
seconds or so if every medium failed.

A screen frozen on `mode NETWORK` after the TFTP lines, or a rescue kernel that
answers ping but never mounts its root (SSH refused, no mount request in hl02's
`rpc.mountd` journal) with a `task swapper/0:1 blocked` trace on the console, is
a USB device that failed its cold-start enumeration: the bootloader hangs when
it initializes USB after the network stage and the kernel hangs in
`async_synchronize_full` waiting for the device probe, while warm reboots work
because the devices are already initialized. On 2026-11-07 the device was a
Coral USB accelerator on raspberrypi2's hub; unplugging everything but the boot
disk, then adding the devices back one at a time with the Pi powered off, finds
it. Never plug a hub into a running Raspberry Pi 4 whose boot disk is a
bus-powered USB device: the power dip resets the disk and the root filesystem
goes read-only.

## Read the server's state

On hl02, all read-only:

- The payload: `systemctl status netboot-payload-raspios-lite` and the pin
  stamp, `cat /var/lib/netboot/images/raspios-lite.pin`, which holds the URL and
  checksum of the image the trees under
  `/var/lib/netboot/payloads/raspios-lite/` were unpacked from.
- The hosts in rescue: `ls /run/netboot/tftp` lists the published boot
  directories and `showmount -e localhost` the exports; both are empty when no
  rescue is active. A pending export removal shows in
  `systemctl list-timers 'netboot-export-cleanup-*'`.
- The boot attempts of a client: `journalctl -u dnsmasq` logs the proxy DHCP
  answers and the TFTP requests. On a normal boot the client asks for its
  directory and gets a `not found` line, which is the expected fall-through to
  its disk.

From any lab host, what a client would fetch, with the toggle started, and the
seed the rescue system applies, read on the server:

```shell
curl tftp://10.0.0.5/raspberrypi2/cmdline.txt
ssh hl02.edge.lab.ferrari.how cat /var/lib/netboot/nfs/raspberrypi2/boot/firmware/user-data
```

## Apply the bootloader configuration

A Raspberry Pi host network-boots only when its bootloader (EEPROM)
configuration puts the network first and names its TFTP directory. The
configuration is declared in the host's inventory variables
(`raspberry_pi_bootloader_configuration`); the node role renders it to
`/etc/ferrarimarco-home-lab/raspberry-pi-bootloader/boot.conf` and fails when
the live configuration differs (the
[Network Boot Service specification](../../architecture/network-boot.md) has the
design). Applying it is a manual step, once per host and again whenever that
check fails:

1. Run the node playbook on the host with the `raspberry-pi-bootloader` tag (and
   `untagged`), as the
   [operational scripts guide](../development/operational-scripts.md) describes,
   first with `--check --diff`, then without: the check run only predicts the
   file, the real run renders it. Both fail at the assertion, listing the
   declared and the live values.
2. Find the release the bootloader runs:

    ```shell
    vcgencmd bootloader_version
    ```

    The host's own `rpi-eeprom` package holds its images under
    `/lib/firmware/raspberrypi/bootloader/default/` (`bootloader-2711/default/`
    or `latest/` on newer releases of the package). When the installed release
    is newer than the package's images, as on a host still on Debian 11, copy
    the image from the boot server's unpacked payload through the control
    machine, then confirm it is the installed release: its `BUILD_TIMESTAMP`
    string must equal the `timestamp` that `vcgencmd bootloader_version` prints.

    ```shell
    ssh hl02.edge.lab.ferrari.how cat \
      /var/lib/netboot/payloads/raspios-lite/root/lib/firmware/raspberrypi/bootloader-2711/default/pieeprom-<release>.bin \
      | ssh pi@<host> 'cat > pieeprom-<release>.bin'
    ssh pi@<host> 'strings pieeprom-<release>.bin | grep BUILD_TIMESTAMP'
    ```

3. Silence the host's availability alerts as the
   [monitoring operations guide](./monitoring.md) describes, then stage the
   update and reboot. The bootloader flashes itself at the next boot:

    ```shell
    sudo rpi-eeprom-config --apply \
      /etc/ferrarimarco-home-lab/raspberry-pi-bootloader/boot.conf \
      pieeprom-<release>.bin
    sudo reboot
    ```

    Pass the image: without it the tool patches the newest image of its own
    package, which downgrades the bootloader when the package is older than the
    installed release. `sudo rpi-eeprom-update -r` cancels a staged update
    before the reboot.

4. Run the playbook again with the same tag: the assertion passes.

## Re-image a Raspberry Pi

The workflow of the specification, with the commands of the raspberrypi2
re-image of 2026-11-08 (about three hours with the services down, two of them
spent on the boot failures of the SSD bridge described below). Every playbook
run is limited to the host, and every apply is preceded by a check run; the
first check runs on a fresh system hit two limits of check mode, which the real
runs do not have: the repository module needs `python3-debian` on the host to
predict anything (install it by hand first), and the Docker role's packages look
unavailable until its repository exists.

1. Silence the host for four hours: its instance, the probes of its targets
   (`alertname=~"Blackbox.*ProbeFailed"` with the instance pattern), the backup
   coverage alert by its `host` label, and the replica-pair alerts.
2. Stop the stateful projects and the backup exporter with
   `docker compose --file <compose file> stop`, run the backup unit once
   (`systemctl start restic-backup-workloads.service`, which also runs the
   repository check), and record the snapshot ID from its journal.
3. When the repository key still holds the quoted password of the former Compose
   job, rewrite it before the flash, while that container can still open the
   repository: `restic key passwd --new-password-file` through the job container
   with the unquoted value in a root-only file, then confirm that a hash of the
   file equals a hash of the vault value. The new backup role cannot open the
   repository otherwise.
4. Start the toggle, reboot into the rescue, and run the flash script with the
   image hl02 serves, its checksum, the disk by its stable ID, and the installed
   seed URL (`http://10.0.0.5/installed/<hostname>/`); the confirmation token
   can be piped in. Then stop the toggle and reboot. The flash script writes the
   SSH switch file beside the seed; without it the image boots with sshd
   disabled.
5. The new system answers SSH as `pi` with the bootstrap key after cloud-init's
   first boot (root grown, hostname set). Clear the host's entries from the
   control machine's known hosts (`ssh-keygen -R`); Ansible accepts the new key
   on its own.
6. Playbooks, each checked then applied: `bootstrap.yaml`,
   `container-engine.yaml`, `setup-disks.yaml`, `backup.yaml`, then
   `home-lab-node.yaml` with the stateful stacks held back. The hold-back flags
   must be JSON booleans, a bare `-e start_x=false` is a string that the
   conditionals refuse:

    ```shell
    ADDITIONAL_ANSIBLE_FLAGS="--diff --limit raspberrypi2.edge.lab.ferrari.how -e '{\"start_monitoring_backend\": false, \"start_zigbee2mqtt\": false}'" \
      ANSIBLE_PLAYBOOK_FILE_NAME="home-lab-node.yaml" scripts/run-ansible.sh
    ```

    The node run blocks on `tailscale up` until the login URL is visited, and
    Ansible shows a task's output only when it ends: read the URL on the host
    with `tailscale status --json` (its `AuthURL` field) while the run waits.
    Afterwards, in the admin console: approve the subnet route, delete the old
    node, and rename the new one, which keeps its `-1` suffix on its own.

7. Restore the stateful stacks with `restore-workloads.yaml` from the recorded
   snapshot (dry run, then `restore_apply=true`), naming the Compose service
   that owns the state (`prometheus` for the monitoring backend), then run
   `home-lab-node.yaml` again without the hold-back flags.
8. State outside the snapshots, as the specification lists: the login user's new
   SSH public key goes on the router's authorized keys by hand, its known hosts
   get the router's host key (`ssh-keyscan -p 1025`), and the new job runs once
   by hand (`systemctl start restic-backup-workloads.service`), which also
   clears the backup coverage alert; the former job's snapshot group, the
   restore source, is forgotten later as the backup guide describes.
9. Verify: the containers, the Zigbee coordinator with its restored network, the
   Prometheus history, the backup timers and exporter, `nmcli device` listing
   the Docker veth devices as unmanaged, then a reboot for the serial port
   setting, and expire the silences.

## Move the image pin

The image is pinned by URL and SHA-256 in the `homeLab.netboot.payloads` option
of the `netboot-server` role, with the checksum taken from the `.sha256` file
the vendor publishes next to the image. Once the change is deployed, the payload
unit downloads and unpacks the new image (about 550 MB, a few minutes, and up to
6 GB of free disk during the unpack), the pin stamp changes, and the image and
checksum served under `http://10.0.0.5/images/` follow. A rescue started before
the unit finishes fails as described above; one already running keeps its
export, which was copied from the previous tree.
