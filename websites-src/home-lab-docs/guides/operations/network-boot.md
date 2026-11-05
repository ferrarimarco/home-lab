# Network boot server

This guide covers the boot server on hl02 that the
[Network Boot Service](../../architecture/network-boot.md) specification
describes: how to put a host in rescue and back, how to read the server's state,
and how to move the image pin. The design, the trees, and the toggle semantics
are in the specification; this page holds the commands.

## Start and stop a rescue

A host network-boots only while its toggle on hl02 is started. Starting it
copies the payload's root tree into the host's export (a few gigabytes; the dry
rescue measures how long that takes on hl02) and publishes the host's boot
files:

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

The toggle fails with `payload raspios-lite is not ready` when the payload unit
has not finished downloading and unpacking the image, which happens once per
pin; check the unit as the next section describes and start the toggle again
afterwards.

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

From any lab host, what a client would fetch, with the toggle started:

```shell
curl tftp://10.0.0.5/raspberrypi2/cmdline.txt
curl http://10.0.0.5/seeds/raspberrypi2/user-data
```

## Move the image pin

The image is pinned by URL and SHA-256 in the `homeLab.netboot.payloads` option
of the `netboot-server` role, with the checksum taken from the `.sha256` file
the vendor publishes next to the image. Once the change is deployed, the payload
unit downloads and unpacks the new image (about 550 MB, a few minutes, and up to
6 GB of free disk during the unpack), the pin stamp changes, and the image and
checksum served under `http://10.0.0.5/images/` follow. A rescue started before
the unit finishes fails as described above; one already running keeps its
export, which was copied from the previous tree.
