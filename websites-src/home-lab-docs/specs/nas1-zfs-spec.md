# 📚 Design Specification: nas1 ZFS Storage Layout

## 🎯 Goals & Principles

### 📀 Pool Stability & Growth

- **Separation of Concerns**: Disks are partitioned by type (and size) to ensure
  predictable performance and contain failure domains. Mixing slow spinners and
  fast SSDs is avoided.
- **Expansion Path**: Single-drive "unmirrored" pools can be safely converted
  into mirrored pools later by attaching same-sized drives.

## 🏗️ Architectural Topology

### 1. Boot Pool (`zroot`)

- **Hardware Profile**: Single SSD (unmirrored for now). Same size within the
  pool group.
- **Role**: Host the NixOS operating system, standard binaries, and
  configuration.
- **Security Configuration**:
    - **Unencrypted**: This allows the server to boot unattended without manual
      intervention (power losses, automated reboots).
    - **Risk Assessment**: Fine for home-lab use where the threat model doesn't
      require OS-level obfuscation.

### 2. Data Pool (`zdata`)

- **Hardware Profile**: Composed of 4 hard disks of mismatched sizes. Future
  expansion will favor pairing identical-sized drives to minimize capacity
  waste.
- **Grouping Decision**: Disks grouped into separate pools by size category (or
  isolated vdev groups) to prevent fast writes from bottlenecking on slower
  drives.
- **Mount Base**: All datasets mount semantic paths under `/mnt/data/...`
- **Security Configuration**:
    - **Native ZFS Encryption**: Enabled at the pool/dataset level.
    - **Passphrase-based**: Prompt for the passphrase manually via shell or boot
      sequence when unlocking datasets.

## 📂 Dataset Taxonomy

The following datasets will reside under the `/mnt/data` base:

| Dataset       | Mountpoint              | Role / Rationale                                                    |
| ------------- | ----------------------- | ------------------------------------------------------------------- |
| `movies`      | `/mnt/data/movies`      | Large media files. No special SSD acceleration needed.              |
| `photos`      | `/mnt/data/photos`      | Personal media. Standard HDD access with redundancy.                |
| `documents`   | `/mnt/data/documents`   | Text and office files. Fast search vs. integrity.                   |
| `source_code` | `/mnt/data/source_code` | High-churn files. Ideal for caching or SSD pool if available later. |

## 🛠️ Management & Maintenance

- **Automated Scrubs**: Enabled to verify hash integrity periodically.
- **Snapshot Schedules**: Standard defaults, to be configured once OS profiles
  are active.
