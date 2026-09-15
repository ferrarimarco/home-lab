# Manual changes diary

The design of this home lab is to have a completely declarative configuration,
whenever possible. At times, this is not possible yet because of an
architectural or tooling limitation, so we perform manual changes. The goal is
to eventually get to a state where we don't need this file anymore.

## 2026-09-13

- `raspberrypi2`: manually power-cycled after the host froze (hard lockup
  between 13:39 and 13:42 local time; no kernel, undervoltage, thermal, or
  memory precursors in logs or Prometheus history). The investigation was
  distilled into the
  [unresponsive host runbook](../guides/troubleshoot-unresponsive-host.md);
  follow-ups (hardware watchdog, data-disk SMART test, OS upgrade) are tracked
  in the
  [specs todo list](../specs/README.md#specifications-to-write-and-todos).

## 2026-08-25

- `pve2`: measured the idle power baseline (Supermicro X10SRL-F, Xeon E5-2683
  v4, 256 GB RAM, kernel 6.17.2-1-pve, no VMs or containers running):
    - Wall power: ~45 W (smart plug reads 67 W with pve2 idle and 22 W with pve2
      off; other devices share the plug, so 22 W is the plug baseline). At 0.099
      EUR/kWh, 45 W around the clock costs about 39 EUR/year.
    - RAPL package-0 ~8.7 W, DRAM ~3.3 W; package C6 residency 88.5%, cores ~99%
      cc6. The remainder is HDDs, platform, fans, and PSU losses.
    - Untapped levers (powertop): governor `performance` on `intel_cpufreq`
      (passive), all 10 SATA hosts at `max_performance` link power policy, PCIe
      ASPM policy `default`, most PCI devices with runtime PM `on`. Realistic
      tuned idle is ~30-35 W (~8-13 EUR/year saved). HDD spin-down is excluded
      by policy: pve2 keeps its platters spinning to avoid start/stop wear.
    - Duty-cycle reduction (shutdown plus wake-on-LAN) is the bigger lever if
      pve2 does not need to run around the clock.
    - `ipmitool` is not installed on pve2; lm-sensors only shows `x86_pkg_temp`.
      The ASPEED BMC may expose DCMI power readings if the PSU has PMBus.
    - The short hostname `pve2` does not resolve from the workstation; use
      `pve2.edge.lab.ferrari.how`.

## 2026-08-12

- `pve1`: updated the Beelink BIOS from N95V104 to N95V107 to fix the Eaton UPS
  (Eaton Ellipse PRO 1600 DIN, USB ID `0463:ffff`, `usbhid-ups` driver for
  `nut-driver@eaton-ellipse-pro-1600-din-1`; NUT runs on pve1) failing USB
  enumeration at cold boot (`device descriptor read/64, error -71`), which
  previously only a physical replug recovered. If it recurs:
    - Software recovery on the root port is not possible: the hub has no
      per-port power switching, and the self-powered UPS only resets its USB
      state machine on VBUS loss. Cycling `usb1-port1/disable` in sysfs and the
      old-scheme enumeration quirk were both tried and failed.
    - Fallback plan: place a PPPS-capable USB 2.0 hub (verified with `uhubctl`)
      between the UPS and the host, enabling a true software replug via
      `uhubctl -a cycle`.
    - Keep the Toshiba USB disk (backing hl01's `rpool-usb-1` 885G volume, same
      xHCI controller) directly on the root port, and never unbind the xHCI
      driver while hl01 is running.

## 2026-08-11

- `pve1`: cleaned the clogged heatsink fins and replaced the degraded thermal
  paste after the host (Beelink EQ-series, Intel N100) throttled to its 200 MHz
  floor, pinning VM hl01 at 100% CPU and pushing the Coral PCIe TPU past its
  94.8 degrees Celsius trip point. Diagnostics learned:
    - Trust `platform_coretemp_0` / `x86_pkg_temp` readings; the `acpitz`
      thermal zone on this board reads a bogus ~27.8 degrees Celsius regardless
      of load.
    - The fans are EC-controlled and invisible to the OS (no hwmon fan sensors),
      so "fans look fine in monitoring" carries no information on this host.
    - Coral PCIe TPU health signatures: healthy inference is ~5-10 ms (Frigate
      `/api/stats`); ~200 ms means thermal throttling; the
      `coral_pci_temperature_celsius` metric reads -89.7 when the TPU has
      crashed.
    - Check CPU throttling directly via
      `/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq`.
    - Preventive maintenance: clean the heatsink fins yearly, in early summer.

## 2026-04-23

- `pve2`: manually created (through the Proxmox GUI) two new ZFS pools:
  `tank-hdd-scratch` and `tank-ssd-scratch`. They are intended to be used as
  scratch space for temporary files. Rationale: ZFS Ansible modules are not
  idempotent, and I didn't find a suitable ZFS Terraform provider.

## 2025-04-03

### Notes to create the 100 VM

The following notes describe the manual creation of the `100` VM on `pve1`.
These instructions are a reference that I used as a base to define the `100` VM
Terraform configuration.

1. Create VM:

    ```shell
    qm create 100 --name hl01 --net0 \
      virtio=BC:24:11:D4:F6:64,bridge=vmbr0,firewall=1 \
      --scsihw virtio-scsi-single \
      --machine q35 --ostype l26
    ```

1. Configure CPU and memory:

    ```shell
    qm set 100 --cpu host --cores 2 --memory 8192
    ```

1. Configure the VM to start at boot:

    ```shell
    qm set 100 --onboot 1
    ```

1. Enable QEMU guest agent:

    ```shell
    qm set 100 --agent enabled=1
    ```

1. Import raw disk:

    ```shell
    qm disk import 100 \
    /var/lib/vz/template/raw/debian-12-generic-amd64-20240211-1654.raw local-zfs
    ```

1. Attach and configure disk to the vm:

    ```shell
    qm set 100 -scsi0 \
      local-zfs:vm-100-disk-0,discard=on,iothread=1,size=2G,ssd=1,aio=io_uring
    ```

1. Resize:

    ```shell
    qm disk resize 100 scsi0 8G
    ```

1. Set boot order:

    ```shell
    qm set 100 --boot order=scsi0
    ```

1. Attach and configure a second disk from the `rpool-sata pool`:

    ```shell
    qm set 100 -scsi1 \
      rpool-sata:vm-100-disk-0,discard=on,iothread=1,size=113G,ssd=1,aio=io_uring
    ```

1. Attach and configure a third disk from the `rpool-usb-1` pool:

    ```shell
    qm set 100 -scsi1 \
      rpool-usb-1:vm-100-disk-1,discard=on,iothread=1,size=885G,ssd=1,aio=io_uring
    ```

1. Enable UEFI and create a UEFI disk volume:

    ```shell
    qm set 100 --bios ovmf
    ```

1. Configure UEFI disk volume:

    ```shell
    qm set 100 --efidisk0 local-zfs:0,efitype=4m
    ```

    If you need to enable Secure Boot, add the `pre-enrolled-keys=1` option.

1. Configure cloud-init datasource:

    ```shell
    qm set 100 --cicustom
    "user=local:snippets/cloud-init-hl01-user-data.yaml,network=local:snippets/cloud-init-hl01-network.yaml"
    ```

1. Configure cloud-init drive:

    ```shell
    qm set 100 --ide2 local-zfs:cloudinit,media=cdrom
    ```

1. Pass the Coral PCIe module to the VM, mark it as a PCIe device:

    ```shell
    qm set 100 --hostpci0 0000:03:00,pcie=1
    ```

1. Pass the iGPU to the VM, mark it as a PCIe device, make the firmware ROM
   visible to the guest, set it as the primary GPU:

    ```shell
    qm set 100 -hostpci1 0000:00:02.0,pcie=on,rombar=on,x-vga=on
    ```

1. Start the VM:

    ```shell
    qm start 100
    ```
