# Raspberrypi2 stability issues

Status: unresolved. This document records the symptoms, the theories we tested,
and the current mitigations, so we don't lose progress between episodes.

The `raspberrypi2` host (Raspberry Pi 4 8GB, Argon One M.2 case, powered USB3
hub with a Coral USB accelerator, a Western Digital MyBook disk, and a Sonoff
Zigbee dongle) freezes or becomes unreachable at irregular intervals, over
multiple years, power supplies, and peripheral configurations.

## Symptoms

- The network stack becomes unavailable: the host stops responding on the
  network.
- The Argon One M.2 case (USB to SATA bridge) appears to disconnect.
- USB resets in the kernel log:

    ```text
    Apr 19 08:53:54 raspberrypi2 kernel: sd 0:0:0:0: [sda] tag#26 uas_eh_abort_handler 0 uas-tag 8 inflight: CMD
    Apr 19 08:54:02 raspberrypi2 kernel: sd 0:0:0:0: [sda] tag#26 CDB: opcode=0x85 85 06 20 00 00 00 00 00 00 00 00 00 00 00 e5 00
    Apr 19 08:54:02 raspberrypi2 kernel: sd 0:0:0:0: [sda] tag#18 uas_eh_abort_handler 0 uas-tag 1 inflight: CMD OUT
    Apr 19 08:54:02 raspberrypi2 kernel: sd 0:0:0:0: [sda] tag#18 CDB: opcode=0x2a 2a 00 00 20 33 28 00 00 20 00
    Apr 19 08:54:02 raspberrypi2 kernel: scsi host0: uas_eh_device_reset_handler start
    Apr 19 08:54:02 raspberrypi2 kernel: usb 2-2: reset SuperSpeed USB device number 3 using xhci_hcd
    Apr 19 08:54:02 raspberrypi2 kernel: scsi host0: uas_eh_device_reset_handler success
    Apr 19 08:54:02 raspberrypi2 udisksd[432]: Error performing housekeeping for drive /org/freedesktop/UDisks2/drives/KINGSTON_SA400M8240G_50026B768544D6F8: Error updating SMART data: Error sending ATA command CHECK POWER MODE: Unexpected sense data (g-io-error-quark, 0)
    ```

- Metrics behavior is inconsistent across episodes: the original analysis
  observed Prometheus still collecting samples during an episode, and inferred
  from that that the file systems were still mounted. Later episodes show holes
  in metrics collection, so neither continued scraping nor the
  mounted-file-systems inference can be assumed. Record the metrics behavior of
  each episode as a data point.

## Theories tested

- Excessive USB power draw from the Raspberry Pi 4 USB hub: the Coral USB
  accelerator can draw a peak current of 900 mA (needs at least 500 mA), and the
  Kingston SSD draws up to 123 mA.
    - Tried a 4 A power supply: it didn't solve the issue.
    - Deployed a powered USB hub: the issue keeps occurring.
- `usb-persist` is enabled, as expected.
- Open lead: check whether the Argon One case has the
  [extra pin](https://forum.argon40.com/t/need-to-remove-and-then-connect-usb3-bridge-to-boot-after-installing-m-2-sata-drive/1199)
  to get power from the 5 V rail directly.

Similar experiences:

- [Frigate + USB Coral + external SSD](https://community.home-assistant.io/t/frigate-usb-coral-external-ssd/347913)
- [Benchmarking machine learning on the Raspberry Pi 4 Model B](https://www.hackster.io/news/benchmarking-machine-learning-on-the-new-raspberry-pi-4-model-b-88db9304ce4)

## The 2026-09-13 freeze

The host hard-locked between 13:39 and 13:42 local time, with no kernel,
undervoltage, thermal, or memory precursors in the logs or in the Prometheus
history, and required a manual power cycle. The investigation is recorded in the
[manual changes diary](./manual-changes-diary.md#2026-09-13) and was distilled
into the
[unresponsive host runbook](../guides/troubleshoot-unresponsive-host.md).

## Leading suspect

The outdated kernel is currently the most plausible culprit: the host runs
Debian 11 (bullseye), past LTS end of life, with an April 2023 kernel. The
corresponding next step is the operating system upgrade, tracked in the
[specs todo list](../specs/README.md#specifications-to-write-and-todos): a
re-image with current Raspberry Pi OS, which is the most supported path for the
Raspberry Pi 4 hardware (the Raspberry Pi OS documentation strongly discourages
in-place upgrades, recommending a re-image instead). A NixOS migration was
considered and deferred: reconsider it after the planned container migration to
hl01 shrinks this host's role.

## Current mitigations

- The systemd hardware watchdog is armed: `RuntimeWatchdogSec=15` (the maximum
  the BCM2711 platform watchdog supports), configured by the
  `ferrarimarco_home_lab_node` role, so a hard lockup should now self-reboot the
  host within 15 seconds. The end-to-end validation with a deliberate kernel
  crash is still pending, tracked in the
  [specs todo list](../specs/README.md#specifications-to-write-and-todos).

## Other open follow-ups

Tracked in the
[specs todo list](../specs/README.md#specifications-to-write-and-todos): the
SMART long self-test on the WD30EZRX 3TB data disk, and the operating system
upgrade. Additional ideas from the original investigation:

- Monitor the USB power consumption
  ([reference](https://unix.stackexchange.com/questions/81508/get-power-consumption-of-a-usb-device)).
- The Argon One case extra-pin check above.
