# Manual Changes Diary

The design of this home lab is to have a completely declarative configuration,
whenever possible. At times, this is not possible yet because of an
architectural or tooling limitation, so we perform manual changes. The goal is
to eventually get to a state where we don't need this file anymore.

## 2026-04-23

- `pve2`: manually created (through the Proxmox GUI) two new ZFS pools:
  `tank-hdd-scratch` and `tank-ssd-scratch`. They are intended to be used as
  scratch space for temporary files.
