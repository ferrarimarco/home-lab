# Home lab architecture

This section describes the architecture of the home lab: one design
specification per subsystem, whose status table tells design from reality, the
reference pages beside them, and the todo list for the whole lab.

## Specifications Directory Index

| Specification                                                               | Description                                                                                                                                                                                                                                                         | Current Implementation Status |
| :-------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :---------------------------- |
| [**Home Lab Bootstrapping**](./home-lab-bootstrapping.md)                   | Global VM installation infrastructure: Nix-native custom installer ISO, secure bootstrap key loading with Git-tracking guardrails, and `nixos-anywhere`.                                                                                                            | **Fully Implemented**         |
| [**NixOS VMs on Proxmox**](./proxmox-vm.md)                                 | Reusable framework for NixOS VMs: the `proxmox-vm` role, host structure with Disko layouts, and the Terraform VM provisioning pattern.                                                                                                                              | **Fully Implemented**         |
| [**Declarative Integration Testing**](./declarative-integration-testing.md) | Design of the NixOS test generator framework (`make-test.nix`), dynamic test discovery, and parallel GHA matrix CI pipeline.                                                                                                                                        | **Fully Implemented**         |
| [**NixOS LXC Containers on Proxmox**](./proxmox-lxc.md)                     | Reusable framework for NixOS LXC containers: the `proxmox-lxc` role, `system.build.tarball` templates, and the Terraform provisioning pattern.                                                                                                                      | **Fully Implemented**         |
| [**NAS LXC Container**](./nas-lxc-container.md)                             | NixOS LXC containers on each Proxmox node exposing host ZFS datasets as SMB shares via bind mounts, plus the Syncthing service. Builds on the `proxmox-lxc` framework.                                                                                              | **Partially Implemented**     |
| [**Monitoring Alerting**](./monitoring-alerting.md)                         | Prometheus Alertmanager in the monitoring backend stack: Telegram notification routing, the severity model, the alert rules catalogue, and the highly available backend pair.                                                                                       | **Fully Implemented**         |
| [**Network Boot Service**](./network-boot.md)                               | Boot server on hl02 that network-boots any lab host on demand through a per-host toggle: the Raspberry Pi path (proxy DHCP and TFTP) now, x86 PXE deferred, the vendor image over NFS as the first payload, and Raspberry Pi re-provisioning as the first consumer. | **Partially Implemented**     |
| [**Backups**](./backups.md)                                                 | Restic backups of the workload state on the Debian hosts: one repository per host on the NAS share, the declared-coverage model, and the verification ladder from structural checks to the monthly restore drill.                                                   | **Partially Implemented**     |
| [**MQTT Broker**](./mqtt-broker.md)                                         | The Mosquitto broker for the smart home workloads as a NixOS module on hl02: the `mosquitto` role, its integration test check, the TCP probe, and the cutover from the raspberrypi2 Compose stack.                                                                  | **Fully Implemented**         |

## Reference pages

Pages that live beside the specifications without being one (no status table, no
row in the index):

- [Software candidates](./software-candidates.md): the software considered for
  each need of the lab, in use or candidate.
- [References](./references.md): external articles and directories behind the
  lab's choices.

## Specifications to write and TODOs

This section is the centralized list of future work and todo items for the whole
home lab; specifications carry no future work sections of their own. Items are
grouped by theme, and stay here until they are implemented and reflected in the
relevant specification, or explicitly discarded. The software considered for
each need, in use or candidate, is tracked in
[Software candidates](./software-candidates.md): only active evaluations become
items here. An item is work with a next step: a decision that has been taken
leaves the list once the owning specification records it, and an undated idea
with no first step waits in the [Ideas](#ideas) subsection until it gets one.

### Current focus

The items being actively worked toward, in priority order (data-loss and
reliability risks first, then security exposure, then automation):

- None: the raspberrypi2 re-image of 2026-11-08 and its follow-ups closed on
  2026-11-09; the next focus is to be chosen from the sections below.

### Bootstrapping and provisioning

- **Power on hosts through their BMC from
  `ferrarimarco_home_lab_boot_bare_metal` (2026-10-28)**: the role only sends
  Wake-on-LAN packets to every MAC in `network_interfaces` and waits for SSH.
  First verify that path: the packets are sent from inside the Ansible
  container, delegated to localhost, and the runner does not use host
  networking, so the broadcast may never leave Docker's bridge (a packet sent
  from raspberrypi2 did wake pve2 on 2026-10-06, so the host side works: the
  i210 reports `Wake-on: g`). Test the playbook against pve2 while it is off,
  watching the plug; if it fails, run that playbook with host networking or
  delegate the send to a LAN host. Then, for hosts that declare a BMC address
  (pve2 does, reserved on the gateway as `pve2-bmc`), use
  `community.general.ipmi_power` before the SSH wait, delegated to the control
  machine, with the credentials from the vault; it needs the `pyghmi` library in
  the Ansible container image.
- **Manual steps left in the provisioning of a new host**: copy the ESPHome
  secrets; configure the Ansible Vault password file and the per-host vault
  files; configure the SSH keys; join the host to the tailnet (`tailscale up` is
  interactive, one run per node; the
  [NAS spec](./nas-lxc-container.md#134-node-identity-and-joining) records the
  deferral and the candidates); configure unattended updates for the Nix hosts
  (the Debian hosts and the Proxmox nodes are covered for the Debian origins by
  the node role's
  [unattended-upgrades](https://wiki.debian.org/UnattendedUpgrades) stack; the
  Proxmox origin stays manual, see the item on automating the Proxmox updates
  under [Host configuration](#host-configuration)); run Ansible; run Terraform
  (networking; the storage stack is applied on both nodes).
- **Network boot service follow-ups**, per the
  [Network Boot Service](./network-boot.md) spec:
    - A second server instance on pve2, so that pve1 and hl02 are covered too.
      It must be a standby that answers only while the hl02 instance is down, or
      share its toggle state: the bootloader takes the first "Raspberry Pi Boot"
      reply and gives up when that server has no directory for the host. Depends
      on: the x86 PXE path (deferred, see the spec) and the pve2 power reduction
      ([Host configuration](#host-configuration)).
    - Declared rescues beside the toggle command (deferred on 2026-11-05 until
      the dry rescue of 2026-11-07 had exercised the command path): a `rescue`
      flag per host in the `netboot-server` role that starts the toggle at boot
      and at activation; a reconcile step acting only on the hosts whose
      declaration changed since the previous activation, so a rescue started by
      command survives unrelated deployments; a boot-time purge limited to the
      undeclared hosts; a start that keeps an existing export. Then decide
      whether the command path stays (hybrid) or the flag becomes the only way
      to start and stop a rescue (two deployments per rescue, none while the
      deployment path itself is broken).
    - Documentation: the provisioning guide (EEPROM editing from the OS, the
      rescue procedure, the manual follow-ups), the restore recipe
      ([Backup](#backup)), and the unresponsive host runbook.

### Issues to solve

- **Recurring cam-3 ffmpeg VAAPI decode crashes on hl01** (about 11 per hour:
  `Failed to sync surface` then `hwdownload` failures; they persist over RTSP
  TCP, so stream transport corruption is ruled out). Hardware acceleration stays
  enabled by decision (2026-09-23): the Frigate watchdog recovers capture each
  time and the Frigate alert rules watch for lasting degradation. Angles: Intel
  media driver and kernel versions, the camera sub-stream H.264 parameters,
  Frigate and ffmpeg updates.
- Frigate doesn't restart because the cam3 name is not yet available. Restart it
  manually from the Frigate UI.
- Home Assistant doesn't connect to Zigbee2MQTT and Telegram (DNS error):
  `/etc/resolv.conf` is empty. Need to wait for the host network to be ready?
- **Budget the hl01 root disk**: Frigate's storage maintainer frees recordings
  only when the free space drops below one hour of camera bandwidth (about 1.8
  GB), so the free space oscillates around that floor, which on a 38 GB disk
  matched the 5 percent `NodeFilesystemSpaceCritical` threshold and made the
  alert flap (2026-10-04, fixed by growing the disk to 64 GB). Size the disk for
  retention days times daily recording volume (about 1 GB per day) plus the
  Prometheus TSDB growth under its 60-day retention, and resize before the
  headroom shrinks to that floor.
- raspberrypi2 stability follow-ups (the
  [stability notes](../archive/raspberrypi2-stability-issues.md) record the
  episodes):
    - Optionally prove the hardware watchdog recovery path end-to-end with a
      deliberate kernel crash (`echo c > /proc/sysrq-trigger`): the host should
      self-reboot within the 15 second timeout. Schedule it consciously, since
      it has the usual unclean-shutdown cost.
    - Prune the unreferenced `vault_raspberrypi2_monitoring_nut_*` variables
      from the raspberrypi2 Ansible vault (NUT moved to pve1; the host_vars
      references were removed on 2026-09-14).
- **ONT hang and power cycle (2026-11-04)**: the ZTE ONT hangs in a state that
  only a power cycle clears, as the
  [ONT notes](../archive/ont-connection-instability.md) record; its admin
  interface has no reboot control and the device keeps no log, so a smart plug
  is the only remote recovery lever and the router log the only record of an
  outage start ([Networking](#networking) has the log retention item). Design to
  assess: a Zigbee plug on the ONT (whether it sits on one of the studio plugs
  today is not recorded), switched over a path that does not need the WAN
  (Zigbee2MQTT on raspberrypi2 and the MQTT broker on hl02, from a Home
  Assistant automation or from the WAN check unit) when the check has failed for
  several consecutive runs with the gateway's Ethernet link up and no PPPoE
  reply, at most one cycle per hour. Failure modes to weigh: a cycle during an
  ISP outage is wasted but harmless; the plug, Zigbee2MQTT, and the check all
  depend on raspberrypi2; an ONT reboot drops the WAN for about a minute, so the
  trigger must not fire on a short blip (the check's `fails=1` setting is the
  current sensitivity). Depends on: the WAN check telling an ONT hang from an
  ISP outage ([Networking](#networking)).

### Reliability and resilience

- **raspberrypi2 root filesystem stall watchdog (postponed 2026-10-13)**: the
  armed hardware watchdog only resets a hung kernel, while the host's failure is
  a root I/O stall that PID 1 survives. The design reviewed on 2026-10-12 is
  recorded in the
  [stability notes](../archive/raspberrypi2-stability-issues.md#root-filesystem-stall-watchdog-design),
  so the next attempt starts from it. Postponed because a rehearsal only proves
  that the unit reboots the host when its own probe hangs; whether the probe
  sees the real failure needs a way to trigger the stall deliberately (a
  controlled reset or power cut of the USB bridge), and a watchdog that can
  reboot the alerting backend's host for the wrong reason is worse than none.
  Depends on: a reproducible trigger for the stall, to be designed with the UAS
  quirk ([Host configuration](#host-configuration)). Until then a stall means a
  power cycle.

### Security

- **Pin every GitHub Action to a commit SHA**: 4 of the 14 third-party actions
  the workflows use are SHA-pinned, the rest by tag, and
  `config/lint/zizmor.yaml` ignores the `unpinned-uses` audit for twelve
  workflows until they are. Pin them with the release tag in a trailing comment
  and drop the ignores.
- Restrict the Frigate configuration file to root only (the node role renders it
  with mode `0640` today).
- **Mosquitto encryption, authentication, and mTLS**: the broker runs on hl02 as
  a NixOS module ([MQTT Broker](./mqtt-broker.md)) that takes password files and
  certificates from paths on the host, so this needs a secret delivery path for
  the NixOS hosts, which none has yet (the open listener needs none).
- **NixOS hardening, in order of intrusiveness**: enable the NixOS firewall with
  the Tailscale interface trusted; harden each service unit with the systemd
  sandboxing directives (ProtectSystem, ProtectHome, NoNewPrivileges, the
  ProtectKernel family), using `systemd-analyze security` as the yardstick;
  audit every `execve` with the kernel audit subsystem and ship the logs off the
  host; strip the default packages. Later options: an ephemeral root with opt-in
  persistence (impermanence or preservation), and `noexec` on every mount except
  the Nix store, which can break Nix builds and needs a break-glass path back.

### CI/CD, infrastructure-as-code, and GitOps

- Publish the artifacts that GitHub Actions already builds (the Proxmox images
  and the NixOS host configurations, in the Nix workflow), and later build them
  in a self-hosted pipeline (Gitea or Forgejo) once one exists, so consumers
  fetch pinned artifacts instead of depending on a local build. Related: the
  automated template upload item ([NAS](#nas)).
- Compose:
    - Move secrets to
      [Docker Compose secrets](https://docs.docker.com/compose/use-secrets/).
    - Move environment variables to env files.
    - Replace FlareSolverr's anonymous `/config` volume (a browser cache that
      its image declares, the only volume in the fleet as of the 2026-10-10
      audit) with a declared bind mount or `tmpfs`, so every stack keeps its
      state in the two backed-up trees the [Backups specification](./backups.md)
      names.
- Terraform:
    - **Bring the Cloudflare configuration under Terraform (2026-10-19)**:
      Cloudflare is the authoritative name server for the root zone
      (`ferrari.how`), configured by hand in its dashboard today. Manage the
      zone and its records with the
      [Cloudflare provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/zone)
      in a numbered stack under `config/terraform/`, with the API token in an
      untracked tfvars file per the secrets policy, and start with a
      `terraform import` of the existing zone and records so the first apply
      changes nothing.
    - **Tolerate powered-off Proxmox nodes**: every stack configures a provider
      per node, so a single unreachable node (pve2 stays off until its power
      reduction completes, see [Host configuration](#host-configuration)) fails
      the whole `run-terraform.sh` sequence, even for changes that only touch
      pve1 resources. Candidates: split the multi-node stacks into per-node
      stacks and let `run-terraform.sh` select which to run; check whether the
      `bpg/proxmox` provider can defer node connectivity until a resource needs
      it.
    - Factor the per-host NixOS VM resources into a shared module (or `for_each`
      over a host map), so the reference pattern of the
      [VM framework spec](./proxmox-vm.md) is enforced by code rather than by
      convention; hl02 is the second VM, declared next to hl01 in the workloads
      stack.
- Tests to implement:
    - Samba config file validation: `testparm -s`.
    - Evaluate `dnsmasq --test` for testing the dnsmasq configuration.
    - Validate the Unbound configuration: `unbound-checkconf unbound.conf`.
    - [Home Assistant config check](https://www.home-assistant.io/common-tasks/container/#configuration-check).
    - [Docker config validation](https://github.com/moby/moby/pull/42393).
    - **Guard the workload state convention (2026-10-12)**: the weekly Docker
      prune runs with `--all --volumes`, which is safe only while every stack
      keeps its state in bind-mounted directories under the backed-up trees and
      never in named or anonymous volumes. Add a check that fails when a compose
      definition declares a volume or mounts one: render the compose files and
      inspect `docker compose config --format json` (top-level `volumes` empty,
      every mount of type `bind`), inside the Molecule run or as a standalone
      step, independent of Ansible where possible since the long-term direction
      is Nix. Volumes declared by an image stay out of reach without a pull and
      hold no state by the same convention.
    - Declare one rsync module in the Molecule inventory (2026-10-18): the test
      host enables the rsync daemon without `rsync_daemon_modules`, so the loop
      that builds the daemon's templates list never runs in CI, and a defect in
      it only fails on hl01.
- Ansible:
    - Read the effective SSH policy after the writes (2026-11-10): the node
      role's lockout assertion reasons about the variables, and `lineinfile`
      appends a missing directive at the end of `sshd_config`, where an active
      `Match` block would scope it, so the global policy could differ from the
      declared one while the run reports converged (no lab host has such a
      block). Read `sshd -T -C user=<ansible_user>` after the writes and assert
      `permitrootlogin` and `allowusers` against the declaration, or insert the
      directives before the first `Match` line.
    - **The Coral role cannot tell the gasket package builds apart
      (2026-11-04)**: the community builds of `gasket-dkms` all carry the
      upstream version `1.0-18`, and the apt module skips a package file whose
      version is already installed, so the pinned 2026 build never replaced the
      2024 Google package on hl01 and the DKMS source stayed unpatched until the
      Debian 13 kernel failed to build it (the release upgrade procedure of the
      [Linux administration notes](../guides/useful-linux-admin-commands.md) has
      the recovery). Compare the installed source with the pinned package (the
      package's `md5sums` against `/usr/src/gasket-1.0`, or a marker holding the
      installed file's checksum) and reinstall through `dpkg -i` on a mismatch.
    - **The detached dist-upgrade task does not protect the controller side
      (2026-11-04)**: on hl01's release upgrade the async job finished on the
      host, but the controller's worker process died after the first polls and
      the play kept printing polls without contacting the host until stopped.
      Run the upgrade through a transient systemd unit (`systemd-run --wait`, as
      the backup role runs its jobs), which a lost controller leaves running and
      whose result the next run can read, or make the poll loop fail on an
      unreachable host.
    - Get the Proxmox VMs data from the inventory instead of the `proxmox_vms`
      list.
    - Move the handlers to a dedicated role and reuse it across all playbooks.
    - Cover the `gateway-dnsmasq` playbook in Molecule (deferred 2026-10-28):
      the default scenario has no `nvram`, so the playbook is not in the CI
      matrix and the check run against the router is its test. A prepare step
      installing stub `nvram` and `service` scripts on the test instance, with
      the gateway host pointed at that instance, would exercise the role's
      rendering and read-then-act logic in CI.
    - Refactor the Molecule tests to use `group_vars` and `host_vars` instead of
      redefining variables in the Molecule file
      ([reference](https://ansible.readthedocs.io/projects/molecule/configuration/#molecule.provisioner.ansible.Ansible)).
    - Set the hostname (`/etc/hostname`: simple hostname).
    - Validation: check that `start_xxxx` and `stop_xxxx` don't contradict each
      other.
    - Cleanup users after switching from appending groups to creating dedicated
      users: set the "state" of users dynamically.
    - Tailscale: don't run `tailscale up` if the flags didn't change between
      runs.
    - **Cut the Molecule workflow cost (measured 2026-10-12)**: each of the
      eight matrix jobs rebuilds the same Ansible container image (220 to 230 s
      each, about 30 of the 55 job-minutes of the last green run, 2026-09-29),
      because they all build at once before any has written the shared cache.
      Build the image once in a job the matrix depends on (push it to the GitHub
      container registry, or warm the `gha` cache). Then reconsider the matrix:
      `main` imports every other playbook, so the seven standalone jobs only add
      per-playbook attribution and a standalone-run check, while
      `home-lab-node`, the most-changed playbook, is tested only through `main`;
      the idempotence phase stays.
    - **Cut the Molecule converge time (measured 2026-10-23 on `main` against
      the Debian 12 image)**: connection pipelining cut the converge from 6:34
      to 4:53 and the idempotence pass from 4:11 to 2:34; a run scoped to one
      stack takes about 1:47 and 0:57. What remains is about 0.2 s of fixed cost
      per task across some 370 tasks, the four file loops of the node role
      (about 50 s per pass, one module execution per item), and three levers not
      taken yet: a test instance image layered on the geerlingguy image with the
      role's packages pre-installed (about 110 s per converge), built by the
      container image workflow with its package list derived from the role's
      variables so it cannot drift; the bootstrap role's untagged apt cache
      refreshes and repository loops (48 s and 23 s in a scoped run), paid by
      every scope; a persistent Molecule cache directory mounted by the script,
      so a `converge` can be followed by `idempotence` or `login` from a second
      invocation.
    - **Make the `home-lab-node` playbook pass a standalone Molecule run
      (2026-10-12)**: the Docker prune unit the node role renders requires
      `docker.service`, which only the container-engine playbook installs, so
      restarting it on the test image fails with "Unit docker.service not
      found". Either declare the Docker role as a dependency of the node role,
      or skip the Docker-bound units when Docker is not installed (and still
      render them). Blocks: testing `home-lab-node` on its own in the Molecule
      matrix, in the workflow cost item above.
- **Migrate from Dependabot to Renovate**, so a single tool manages all
  dependency updates. Renovate is configured (`.github/renovate.json`) behind
  Dependency Dashboard approval and covers sources Dependabot does not (Ansible
  Galaxy requirements, pre-commit hooks, the `_VERSION` variables in Dockerfiles
  and scripts). Decide on the approval flow, port the grouping, then remove
  `.github/dependabot.yaml`. Dependabot multi-ecosystem groups were abandoned on
  2026-09-29 because group pull requests stopped updating after creation.
- **Move the monitoring stack from the node role to the monitoring role**: the
  node role deploys the containerized exporters and textfile collectors on
  Docker hosts while the monitoring role installs the Debian packages on the
  Proxmox nodes, so the apt success-stamp snippet lives in both (2026-10-12);
  the monitoring playbook also targets every host with no gate, so it must run
  with a host limit until the roles merge.
- **pve2's first full node run and its kernel command line (deferred on
  2026-11-10, waiting on the host)**: pve1 had its first full
  `home-lab-node.yaml` run on 2026-11-10 (key-only root SSH with password
  authentication off, fail2ban, unattended-upgrades for the Debian origins, the
  role's apt and SMART collectors off beside Debian's, the static metrics in the
  packaged exporter's directory, no package removed) after a manual
  `apt full-upgrade` and reboot cleared a 189-package backlog, and a second
  check predicted nothing; the
  [Ansible development guide](../guides/development/ansible.md) describes the
  node settings and the two guards that made the run safe. pve2 has been off
  since 2026-11-04 and repeats the sequence when it is back: the OS packages
  playbook limited to the host, a reboot, the node playbook (check first; the
  group variables already hold its settings), then `proxmox-node.yaml`, whose
  kernel task now reads the boot layout and writes the IOMMU options to
  `GRUB_CMDLINE_LINUX_DEFAULT` with `update-grub` on a GRUB host, followed by a
  reboot. On pve1 the `proxmox-node.yaml` run of the same day found the kernel
  line converged.
    - Deferred the same day: the Samba configuration file guard. The
      network-shares stack removes `/etc/samba/smb.conf` wherever it is
      disabled, the debconf-generated file of `samba-common` included (pve1 lost
      its sample on 2026-11-10, harmless there: no smbd, and smbclient falls
      back to defaults). Render the template with a marker and remove the file
      only when the marker is present, so a host that never enabled the stack
      keeps the file its packages generated.
- The `raspberry_pi_sense_hat_apt_packages` list in the node role's Raspberry Pi
  variables is referenced by no stack (read on 2026-11-10): the sense-hat
  package has never been installed or removed by the stack machinery. Wire it
  into the sense hat stack or drop it.
- Nix tests:
    - Modularize the integration-test generator: move the per-service test
      fragments (SSH, QEMU guest agent, comin, Samba, ...) out of
      `config/nix/tests/make-test.nix`, for example next to each role, so the
      generator stays maintainable as service coverage grows. Do it for all
      services at once to avoid a split paradigm.
    - Check that configured users are present.
    - Check that configured users have their SSH keys authorized (reuse the
      existing bootstrap key check, which already does most of the work).
- Reusable workflow calls with the self-repository syntax: GitHub recommends
  `uses: $/.github/workflows/<file>` over the workspace-relative `./` form, and
  zizmor's `self-repository` audit flags the `./` call in
  `website-ferrarimarco.github.io.yaml`, but actionlint 1.7.12 (the newest
  release, bundled in super-linter v9.0.0) rejects the `$/` form, so the audit
  is ignored in `config/lint/zizmor.yaml` (2026-10-18). Switch the call and drop
  the ignore once actionlint accepts the syntax.
- **One Git worktree per agent session (parked on 2026-11-06, waiting for a
  decision)**: the agent sessions that work on this repository share one working
  tree, one index, and one branch, which is why the guides and the agent skills
  carry a rule per shared resource. A worktree per session that changes code
  (`claude --worktree <name>`) would keep the changes of each session apart by
  construction. Untried; the costs to settle first: the committed `docs/` output
  conflicts whenever two branches rebuild it (CI committing the site on master
  would remove the conflict; `.github/workflows/documentation.yaml` commits only
  on pull requests today, parked on 2026-10-22); nearly every change edits this
  index, so it will sometimes conflict; the gitignored vault files need the hard
  links the
  [operational scripts guide](../guides/development/operational-scripts.md)
  describes for a temporary worktree, and where the Terraform state lives was
  not checked; a playbook apply would need a rule to run only from a commit on
  master; the lint and docs containers have fixed names, so those runs stay one
  at a time across worktrees.

### Host configuration

- **Automate the Proxmox package upgrades, with a human in the loop (decided to
  design on 2026-11-10)**: the vendor prescribes `apt full-upgrade` and warns
  that `apt upgrade` can leave a partially upgraded state; unattended-upgrades
  has the latter's semantics by design (it holds back any step that removes a
  package), so the node role runs it for the Debian origins only and the Proxmox
  origin (pve-manager, the kernel, ZFS) stays manual, nudged by
  `AptUpgradesPending` (191 packages had accumulated on pve1 by 2026-11-10, 34
  of them security fixes). Candidate shapes: a host timer that refreshes and
  downloads, then notifies and waits for a human go before the upgrade and the
  reboot; or a scheduled run of the OS packages playbook from a host that is
  always on (the control machine suspends). Any shape needs a reboot window, the
  guest start ordering on pve1 (hl01, hl02, the NAS container, whose
  `rpool-usb-2` pool had no import unit until the reboot of 2026-11-10 exposed
  it), the `proxmox-ve` apt hook as the only built-in guard against a removal,
  and an alert for a run that failed or never happened. The cost side of the
  rejected automatic variant: unattended removals and hypervisor changes nobody
  reviews, which the staff position in the
  [Proxmox forum thread](https://forum.proxmox.com/threads/is-unattended-upgrade-package-safe-to-use.139808/)
  advises against.
- **Converge pve2's root filesystem and bootloader with pve1's (2026-10-22)**:
  pve1 boots a ZFS root through `proxmox-boot-tool` with systemd-boot, which
  keeps every ESP in sync and takes the kernel command line from
  `/etc/kernel/cmdline`; pve2 was installed on LVM with an ext4 root and boots
  through GRUB, so its root has no checksums, compression, or snapshots to roll
  back an upgrade. The Proxmox role's kernel task reads the boot layout and
  writes the GRUB variant since 2026-11-10, not yet run on pve2 (the pve2 first
  full node run item under [CI/CD](#cicd-infrastructure-as-code-and-gitops)).
  Align at pve2's next reinstall by choosing a ZFS root in the installer with
  Secure Boot off (Proxmox falls back to GRUB with it on); a reinstall only for
  this is not worth its cost (guests re-created by Terraform, the data pools
  exported and imported, the NAS container's state directories on the root disk
  carried across).
- **pve2 power reduction before running it 24/7**: the goal is to run pve2
  around the clock, but it stays powered off until its idle draw (about 45 W at
  the wall) comes down. The measurements, the levers with their status, the
  experiment log, the BIOS export, and the decisions taken are in the
  [host power guide](../guides/operations/host-power.md). Remaining steps:
    - Keep watching the SATA link power management the BIOS change of 2026-10-06
      enabled: before declaring the host fit for 24/7 duty, check the kernel log
      for `ata1`-`ata3` resets and the `UDMA_CRC_Error_Count` attributes after a
      few days of uptime, and run a ZFS scrub once the pools hold enough data to
      exercise the links (about 1 GB today).
    - Replace the PSU, last, so it is measured at the final DC load.
    - Deferred until the pve2 workload is defined: the CPU governor, the energy
      performance bias, and the memory frequency, all of which trade performance
      for power under load; compare them with a controlled load on the plug,
      then decide what goes into the BIOS file or the host configuration.
    - The power instrument depends on raspberrypi2 (the Zigbee plugs reach Home
      Assistant through Zigbee2MQTT there); the network coordinator
      ([Smart home](#smart-home)) removes that dependency.
    - Depends on: a stable BMC address for remote recovery during runtime
      experiments ([Networking](#networking)). Blocks: the media second copy on
      `tank-hdd` ([Backup](#backup)); the Proxmox node downtime alerts stay
      enabled by choice until pve2 runs 24/7
      ([Monitoring and alerting](#monitoring-and-alerting)).
- **Prometheus node exporter on the Asus RT-AX86U**: copy the node public key to
  the router, trust its host key on the connecting node, run the arm64 release
  binary from USB storage, relaunch it when not running from a `cru` cron entry,
  add the router to the `node` scrape job, and verify the netdev collector
  reports the interface counters, since some exporter releases failed on this
  firmware
  ([reference](https://www.snbforums.com/threads/successfully-got-node_exporter-on-rt-ax58u.64683/)).
  The stock firmware has no `init-start` hook and its `script_usbmount` variable
  is blocked on recent builds (checked 2026-10-23; the
  [gateway notes](../archive/asus-rt-ax86u-tim-gateway.md#script-launchers-and-firmware-update-signals)
  have the evidence), so the known launcher is the one
  [jacklul/asuswrt-scripts](https://github.com/jacklul/asuswrt-scripts) uses: a
  USB stick carrying a fake Download Master package whose init script starts the
  scripts after the mount. No USB storage is attached to the router today, so
  this item starts with that stick.
- raspberrypi2:
    - Enable TRIM on the external SSD
      ([reference](https://www.jeffgeerling.com/blog/2020/enabling-trim-on-external-ssd-on-raspberry-pi)).
    - Force the Argon One M.2 bridge (ASMedia `174c:1156`, the root SSD) off the
      `uas` driver with `usb-storage.quirks: 174c:1156:u` in the host's
      `raspberry_pi_kernel_command_line_options` (the node role rewrites
      `cmdline.txt` and reboots since 2026-11-09). This is the first mitigation
      for the root storage stalls of 2026-10-06 and 2026-10-07 (see the
      [stability notes](../archive/raspberrypi2-stability-issues.md)); verify
      with `lsusb -t` that the bridge binds to `usb-storage` after the reboot.
    - Test the Argon case's poweroff hook: the node role places it in
      `/usr/lib/systemd/system-shutdown` since 2026-11-09 (it sat in an unread
      directory before), so whether the case cuts the power at the end of a
      poweroff has never been observed. Power the host off on a quiet day,
      confirm the case's LED and fan stop, and record the outcome in the
      [stability notes](../archive/raspberrypi2-stability-issues.md).
    - Stable device path for the Zigbee dongle: the Sonoff dongle (USB ID
      `1a86:55d4`, a QinHeng serial chip) has enumerated at least once with the
      chip's default descriptors ("USB Single Serial" strings and another serial
      number) instead of ITEAD's, so the `by-id` symlink that
      `zigbee_adapter_device_path` names did not exist and Docker refused to
      start Zigbee2MQTT; since 2026-11-07 the project unit would stay inactive
      on its missing required device path instead. Add a udev rule matching the
      vendor and product IDs
      (`SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", SYMLINK+="zigbee_dongle"`),
      which exists under either enumeration, and point the inventory variable at
      its symlink.

### Networking

- **Static addresses for the servers and the address plan (decided
  2026-10-24)**: infrastructure addressing is declared where each host is
  declared, and the DHCP server serves ephemeral clients only. The original
  motivation (after a router reboot, dnsmasq on the gateway doesn't know the
  hosts until they renew their leases, so their names don't resolve) is served
  on the way: a reservation with a hostname already lands in the router's
  `/etc/hosts` when dnsmasq starts (verified 2026-10-23: the five current
  reservations are there as `<address> <hostname>.edge.lab.ferrari.how`), and
  the end state takes the server names off the router altogether. The plan:
    - An infrastructure range outside the dynamic pool (for example
      `10.0.0.0/24`, with the pool starting after it; today the pool spans the
      whole `10.0.0.0/8` from `.2` and reservations are the only exclusion),
      recorded in the inventory as the address plan.
    - A static address per host in its own toolchain: NixOS interface options
      for hl02 (and the future pve2 twin), the cloud-init network data file
      Terraform already stages for hl01, the container network settings for
      nas-pve1 (the NAS static IP migration), the interfaces file the Proxmox
      nodes already have, and the host network configuration the node role
      renders for raspberrypi2. The resolver hosts point at their local Unbound,
      so they boot without the router.
    - Server records in the CoreDNS edge zone, generated from the inventory, the
      gateway's own name included: `gateway.edge.lab.ferrari.how` resolves today
      only because the router writes `gateway.<LAN domain>` to its hosts file,
      and the ChkWAN and ONT units reach the router by that name.
    - Reservations reduced to pool guards during the transition and then to the
      devices whose configuration the lab does not own (the cameras); cam-1's
      manual assignment is no longer needed.
    - Sequence, gated by the resolver switch rather than by the addresses: every
      static host points at Unbound in its own configuration and DHCP clients
      through option 6 before the router's LAN domain changes (network stack
      item below), because afterwards the router knows servers only under the
      client zone and any host still resolving through it loses every server
      name at once. Rejected: renaming the servers into `lab.ferrari.how` (every
      consumer carries the edge names), and CoreDNS owning the edge zone with
      `fallthrough` to the router as the end state (two authorities for one
      zone; kept as the transition device). The pool carve-out and option 6 are
      `gateway_dhcp` values in the inventory, which the `gateway-dnsmasq`
      playbook applies (2026-10-28).
- **Tailscale subnet router on hl02 for general remote access**: one node
  advertising the LAN covers ad-hoc remote access without installing Tailscale
  fleet-wide; service endpoints get direct nodes instead, per the NAS spec's
  [placement rationale](./nas-lxc-container.md#13-tailscale-connectivity).
  Considerations: remote access through an hl02 router is down whenever pve1's
  virtualization layer is, and the physical tailnet fallback (raspberrypi2) is
  being retired, so evaluate keeping a physical device on the tailnet for
  out-of-band reach; route failover is paid, so a second router would not fail
  over on the free plan; the Tailscale Terraform provider can approve advertised
  routes declaratively (`tailscale_device_subnet_routes`).
- WAN check (`asuswrt-check-wan.sh` and its unit):
    - Re-add the ONT route script's NAT rule after each WAN restart:
      `restart_wan` rebuilds the router's firewall and drops the MASQUERADE rule
      the half-hourly `configure-route-to-ont.sh` adds, so the ONT exporter
      loses its path for up to 30 minutes after every restart. Run the route
      script from the check after a restart.
    - Tell an ONT hang from an ISP outage: on 2026-11-04 the check restarted the
      WAN 98 times against a hung ONT, and once more while the ONT was still
      booting after its power cycle. Feed the ONT ARP test and the `eth0` link
      state into the decision (link up, no ARP reply, and no PPPoE reply means
      the ONT), and expose the result for the plug trigger of the ONT item in
      [Issues to solve](#issues-to-solve). Blocks: the ONT hang and power cycle
      item ([Issues to solve](#issues-to-solve)).
- Asus gateway 2.4 GHz Wi-Fi (2026-10-09: clutter placed next to the router
  raised the band's noise floor until the radio reset itself repeatedly and
  dropped every 2.4 GHz client; clearing it restored them):
    - Record the incident, its cause, and the measurements in the manual changes
      diary, and correct the firmware entry there: the router runs
      3.0.0.4.388_24436, while the diary last records 24386.
    - Move the 2.4 GHz band from channel 11 at 40 MHz to channel 1 at 20 MHz:
      the per-channel sweep (`wl -i eth6 chanim_stats all` over SSH) showed
      channel 1 as the quietest, and 20 MHz halves the exposure to the next
      noise source. Record the change in the diary.
    - Investigate the chronic 2.4 GHz radio resets
      (`wl0: fatal error, reinitializing` in the router syslog, about four per
      day, none on 5 GHz): check for a firmware build newer than 24436, and
      consider exporting the reset counter and the noise floor once the node
      exporter runs on the router ([Host configuration](#host-configuration)).
- Network stack
  ([reference](https://www.virtualizationhowto.com/2025/08/how-to-totally-control-dns-in-your-home-lab/)).
  Today: Cloudflare is the authoritative name server for the root zone
  (`ferrari.how`), configured by hand (its Terraform management is a
  [CI/CD](#cicd-infrastructure-as-code-and-gitops) item); the dnsmasq instance
  on the gateway is the DHCP server for the `10.0.0.0/8` subnet, answers the
  `edge.lab.ferrari.how` zone from its DHCP leases
  ([source](https://lists.thekelleys.org.uk/pipermail/dnsmasq-discuss/2008q4/002670.html))
  without being authoritative for it, forwards everything else to its local DNS
  over TLS listener (`dnspriv_enable=1`, verified 2026-10-23), and keeps DHCP
  and lease DNS by decision (2026-10-23), managed through the `gateway_dhcp`
  inventory values the `gateway-dnsmasq` playbook applies. The node role carries
  a network stack (Unbound as the private recursive resolver, CoreDNS as the
  authoritative server for the `lab.ferrari.how` zone) behind
  `configure_network_stack`, which no host enables, so the
  `network-stack-coredns` scrape job renders zero targets, accepted until the
  deployment (2026-10-04). The items below deploy and harden that stack:
    - **DNS server and resolver, placement and staged route (decided
      2026-10-24)**: the three roles stay separate (Unbound resolves, CoreDNS is
      authoritative, dnsmasq serves DHCP), and the resolver pair is the
      availability-critical piece, since the router stops being a fallback for
      infrastructure names once its LAN domain changes. Placement: hl02 now and
      a twin NixOS guest on pve2 once it runs 24/7, the same Nix role on both,
      keepalived between them
      ([pihole-keepalived](https://github.com/matayto/pihole-keepalived)) on a
      VRRP address in the infrastructure range (clients take the first DNS
      server from DHCP and fall back only after per-query timeouts, so two
      addresses give degraded service rather than availability; DHCP needs no
      address of its own, both instances answer broadcasts). hl01 is excluded
      because its CIFS mounts need name resolution before Docker starts, and
      raspberrypi2 stays the fallback for a second node if pve2 stays off for
      long, at the price of a second implementation (the Compose stack). The Nix
      role re-expresses the stack's Unbound and CoreDNS configuration as NixOS
      modules and reads the zone data from a JSON file in the repository, which
      Ansible reads as well, so the records have one home. Stages:
        1. Unbound and CoreDNS on hl02: CoreDNS owns `edge.lab.ferrari.how` from
           the inventory (server records, the gateway record, CNAME aliases for
           services) with the `file` plugin's `fallthrough` to the existing
           forward to the router for client lease names (available since CoreDNS
           1.12.2; the stack pins 1.14.7), plus the reverse zone of the
           infrastructure range with the rest of `in-addr.arpa` forwarded as
           today. DHCP option 6 points at hl02 with the router second.
        2. The twin on pve2 and the keepalived address; option 6 moves to it.
           Depends on: pve2 running 24/7
           ([Host configuration](#host-configuration)).
        3. The router's LAN domain changes to a client zone (a child such as
           `clients.edge.lab.ferrari.how`, which CoreDNS forwards to the router
           by longest match, or a sibling under `lab.ferrari.how`), so dynamic
           clients get a name there within one lease and nothing is renamed; the
           fallthrough is dropped, the pool is carved, and the reservations
           shrink to the cameras (static addresses item above).
        4. Optionally, DHCP taken over by a dnsmasq pair with split pools: with
           the servers static and only the cameras reserved, the pair has
           nothing but the camera reservations to agree on, and lease names stay
           cosmetic. A lab dnsmasq owning DHCP, DNS, and PXE (the design of the
           former `provisioning/docker/dnsmasq` templates, last in the parent of
           commit 0b10e5da: `dhcp-authoritative`, `bogus-priv`, `domain-needed`,
           `expand-hosts`, `no-hosts`, `no-resolv`, TFTP with a `pxe-service`
           entry, and four files re-read on SIGHUP for static hosts, DHCP
           reservations, upstream servers, and DHCP options) gives one
           declarative configuration, CNAMEs included, and lets the DHCP server
           hand out the boot server itself, which drops the proxy-DHCP responder
           of the [Network Boot Service](./network-boot.md) spec; it was
           rejected on 2026-10-23 as the first step, because DHCP and DNS for
           every device in the house would then depend on pve1, hl02, and a
           comin-driven VM.
    - Configure network boot for the x86 Proxmox nodes: the proxy DHCP responder
      of the [Network Boot Service](./network-boot.md) spec runs on hl02 since
      2026-11-05; the x86 path needs its `pxe-service` entry, a boot file
      (candidates: [netboot.xyz](https://github.com/netbootxyz/netboot.xyz),
      [PXE booting into netboot.xyz](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Enable-PXE-booting-into-netboot.xyz)),
      and a payload type.
    - Configure dnsmasq on the Asus router to use the recursive DNS resolver:
      the upstream servers are a UI-exposed NVRAM setting the `gateway-dnsmasq`
      playbook does not manage yet; add the variable to the gateway role when
      this lands (the lab resolver can keep the router's DNS over TLS listener
      as its forwarder instead), and forward the main zone to the authoritative
      server (`server=/{{ root_fqdn }}/{{ root_dns_servers[0].ipv4_address }}`).
    - Unbound: DNS over TLS to its forwarders; DNSSEC validation (trust-anchor,
      auto-trust-anchor); `harden-unverified-glue`.
    - Block port 53 outbound on the router WAN interface, keeping port 53
      allowed within the LAN, since the router serves from DNS over TLS and DNS
      over HTTPS external resolvers.
    - Prevent LAN clients from bypassing the local resolver: NAT-redirect all
      LAN port 53 traffic to it (excluding the resolver itself), block outbound
      port 853 (DNS over TLS and DNS over QUIC), block outbound UDP 443 (QUIC,
      browsers fall back to HTTP/2), and add a DNS-over-HTTPS blocklist by
      domain on the resolver and by IP on the firewall (for example the HaGeZi
      lists). Known gaps: apps that bundle DNS over HTTPS with their application
      traffic, private DNS-over-HTTPS servers, and VPN tunnels.
    - Update the DNS records in `group_vars/all/main.yaml` to point to the DNS
      server, and define the DNS names there: refactor the roles so endpoint
      FQDNs in the vars file are automatically configured; reverse proxy
      (Traefik).
- **4G/5G WAN fallback**: dual WAN failover on the router with a USB modem or a
  tethered phone. It restores service during an ONT or ISP outage (the lab was
  offline for five hours on 2026-11-04) and lets Alertmanager deliver normally,
  at the cost of a SIM and a modem. The WAN check must then probe the primary
  interface (`i=wan0`), since a failover would hide the ONT fault from it.
- **Disable UPnP on the gateway, or at least its PCP logging, and forward the
  router log off the router**: miniupnpd's "Invalid PCP v2 MAP message" lines
  were more than half of the router's 256 KB log on 2026-11-04 and rotated it
  every two hours, so the start of that day's WAN outage was gone by the time
  the log was read. The router's log settings can send syslog to a remote host.

### Monitoring and alerting

- **One metered smart plug per node and one for the network stack**: the studio
  plugs feed several devices each, so every host figure in the
  [host power guide](../guides/operations/host-power.md) is a difference against
  a shared baseline that moves whenever something else is plugged in.
- **Alert on obsolete packages (2026-10-12)**: a package that no configured APT
  source provides anymore (the Coral runtime after Google retired its
  repository, leftovers after a release upgrade) gets no updates and raises
  nothing. The apt collector's `apt_packages_obsolete` metric (upstream
  `apt_info.py` from the 2026-04-20 merge) counts them, but that version reads
  `Package.phasing_applied`, which python3-apt 2.6 (Debian 12) and the
  Debian-packaged collector on the Proxmox nodes lack, so the role pins the
  2026-02-25 version. Once the upstream script runs on the hosts again, bump the
  pin, add a warning rule on `apt_packages_obsolete > 0`, and a dashboard panel;
  skip `apt_packages_per_origin`, an inventory figure with no threshold.
- **Kernel log error exporter (2026-10-10)**: the kernel-level signs of the
  raspberrypi2 data disk failure and of the root SSD stalls (medium errors, a
  USB reset loop, UAS command aborts) carried no metric, while the SMART
  pending-sector alert did fire. Add a textfile collector that keeps a
  cumulative counter per device and signature (block I/O errors, medium errors,
  USB device resets, UAS aborts, ext4 errors) from a journal cursor file,
  alerting with `increase(...[1h]) > 0` as `EdacUncorrectableErrors` does.
- **Asus firmware update alert (2026-10-24)**: two sources disagree on what "new
  firmware" means, so the collector exports both. The router's daily firmware
  check posts to an Asus feedback server and receives the build Asus offers to
  that device under a staged rollout, left in NVRAM as `webs_state_info`,
  `webs_state_flag`, and `webs_update_ts` ("installable from the UI now"); the
  [support page](https://www.asus.com/it/networking-iot-servers/wifi-routers/asus-gaming-routers/rt-ax86u/helpdesk_bios?model2Name=RT-AX86U)
  publishes earlier (24437 on 2026-10-22 while the router still offered 24436),
  is server-rendered, and its JSON API refused direct calls; the
  [gateway notes](../archive/asus-rt-ax86u-tim-gateway.md#script-launchers-and-firmware-update-signals)
  record the NVRAM variables and the log path. Design: a `monitoring-asuswrt`
  textfile stack on the host that holds the router SSH key (raspberrypi2 today,
  next to the ChkWAN and ONT units; it moves with them), modeled on the
  `monitoring-apt` stack: a daily timer reads the running version and the
  `webs_*` values over SSH, takes the highest version string of the form
  `3.0.0.4.<build>_<number>` on the support page with its release date, and
  writes an update-available gauge labelled by running, offered, and published
  version plus a check-timestamp gauge per source. Rules with promtool tests:
  `AsusFirmwareUpdateAvailable` when the published version is newer than the
  running one, its description saying whether the router already offers it; a
  stale-check rule when the page is unreachable or unparsable for two days or
  the router's own check is older than two days. Not in scope: triggering the
  router's check from the lab, and scripts on the router.
- **Declarative Grafana admin credentials**: vault-backed
  `GF_SECURITY_ADMIN_USER` and `GF_SECURITY_ADMIN_PASSWORD` environment
  variables in the monitoring backend compose template, so a fresh replica
  starts with the right account instead of the Grafana defaults; today the
  account exists only in Grafana's local database, seeded from an existing
  replica at bring-up (monitoring-alerting spec §3.3). The variables only apply
  to a freshly initialized database, so existing replicas need a one-time
  in-container `grafana-cli admin reset-admin-password` reading the value from
  the container environment.
- **Probe the pve2 BMC** (ICMP ping, or HTTPS against its web interface) so that
  a host that is powered off but reachable for remote power-on is
  distinguishable from one that is unplugged or whose BMC lost its network. The
  target is `pve2-bmc.edge.lab.ferrari.how`, which the gateway resolves from its
  reservation (2026-10-28).
- **A disabled stack leaves its service enabled (2026-11-08)**: the stacks that
  stop a service when their flag is off keep `enabled: true` on the service
  entry (the monitoring timers, Samba, the camera, the Argon case, the Sense
  HAT), so the unit comes back at the next boot, and a configuration file
  removed with the stack can still trigger a restart of the stopped service
  through `os_services_to_restart`. The Wi-Fi stack, since removed, got both
  fixed on 2026-11-08 (`enabled` follows the flag, no restart list when
  disabled); apply the same shape to the other stacks, with a Molecule case that
  disables one.
- Alerting follow-ups deferred by the
  [Monitoring Alerting](./monitoring-alerting.md) spec:
    - A rule for a Compose project whose unit never ran: since 2026-11-07 a
      project unit requires its device units (`required_device_paths`), and a
      boot without the device fails the start by dependency, which systemd
      records as inactive rather than failed, so `SystemdUnitFailed` stays
      silent and the container rules need a started container. Candidate: an
      `absent()` rule over the container's `container_last_seen` series per
      project the inventory enables, or a check of the unit's last result.
    - Tune the textfile staleness alert threshold per collector (the first
      iteration uses one conservative threshold sized to the slowest daily
      timer, so a stuck frequent collector is detected late; the ONT exporter
      writes every 30 seconds).
    - **Dead-man's-switch**: an always-firing heartbeat alert delivered through
      a channel independent of the Prometheus host, so a dead monitoring backend
      is itself noticed. The 2026-11-04 WAN outage is the motivating case:
      Telegram needs the WAN, both Alertmanager replicas gave up delivery after
      five minutes, and the alerts reached the phone after the manual recovery.
      Candidates: a hosted check that expects the heartbeat and notifies on
      absence (Healthchecks.io, UptimeRobot), which is also the cheapest mobile
      notification for a WAN outage, saying that the lab is unreachable but not
      why; a scheduled GitHub Actions workflow that probes the heartbeat
      endpoint and notifies on failure, with no infrastructure beyond the
      repository. Alternatives that deliver the alert content: the 4G/5G WAN
      fallback of [Networking](#networking), or an SMS modem with a prepaid SIM
      behind an Alertmanager webhook. Not viable: Home Assistant companion push
      (relayed through the cloud), Tailscale (the phone cannot reach the lab
      without the WAN), and local sirens or lights (not mobile).
- Validate the reworked `sense-hat-exporter` unit (venv in a systemd state
  directory, metrics file deleted on start and exit, throttled restarts; changed
  2026-09-14) whenever a host with a Sense HAT returns to service; no such host
  is currently deployed.
- Replace the `rm` ExecStartPre workaround in systemd units that write node
  exporter textfiles (e.g. monitoring-apt) with the `truncate:` variant of
  `StandardOutput` once every host runs systemd >= 248.

### Smart home

- **Sonoff Zigbee dongle firmware and the `ember` driver**: the Sonoff Zigbee
  3.0 USB Dongle Plus V2 on raspberrypi2 runs EmberZNet 6.10.3 (EZSP v8, read
  from the retained bridge info on 2026-10-16), so Zigbee2MQTT 2.x drives it
  through the deprecated `ezsp` driver, which timed out on two of three starts
  at the 2.14.2 upgrade (2026-10-17). Flash EmberZNet 7.4 or later (the firmware
  builders on the
  [Zigbee2MQTT EmberZNet adapter page](https://www.zigbee2mqtt.io/guide/adapters/emberznet.html),
  from a machine with USB access, which the Crostini workstation is not, or from
  raspberrypi2 itself with a flasher container), then switch `serial.adapter` to
  `ember` in the rendered configuration template. The coordinator backup and the
  restic snapshot carry the network, so a reflash that loses it is recoverable.
  The network coordinator (next item) removes the flash-station constraint,
  since those devices update their own firmware.
- **Zigbee coordinator over the network (decided 2026-10-23)**: replace the USB
  dongle with an Ethernet or PoE coordinator, so that Zigbee2MQTT connects to
  the radio over TCP (`serial.port: tcp://<host>:<port>`), runs on any host with
  no USB passthrough, and the radio sits where the mesh needs it; this is the
  decoupling step chosen instead of moving the dongle to pve1. First candidate:
  the SMLIGHT SLZB-06 family (EmberZNet, firmware updated from the device's web
  interface); verify the firmware line, the `ember` driver support, and the
  update path before buying. The coordinator backup carries the network across
  the adapter change, as it does across a reflash.
- Exclude the kitchen presence sensor's illuminance entity from the Home
  Assistant recorder: the device reports it every few seconds by design, which
  fills the database and buries the occupancy history the
  [Zigbee2MQTT operations guide](../guides/operations/zigbee2mqtt.md) reads for
  its measurements.

### Backup

- **Roll out the single-flavour backup role (2026-10-31)**: applied on hl01 and
  pve1 on 2026-11-04 and on raspberrypi2 with its re-image on 2026-11-08, whose
  Compose-era snapshot group was forgotten on 2026-11-09 as the
  [backup operations guide](../guides/operations/backup.md) describes. Left:
  pve2, which follows when it is on (until then the `ResticExporterDown` alert
  fires for its exporter target, left unsilenced by choice). Update the
  [Backups specification](./backups.md) status table as each step lands.
- **Second copy of the restic repositories (2026-10-19)**: the per-host
  repositories on the nas-pve1 `backups` share are the only copy of the Debian
  hosts' state backups, and the share's `rpool-sata` pool is a single-disk vdev
  ([NAS](#nas)), so a disk failure on pve1 loses every backup along with the
  share. Give the offsite or cloud destination of the Destinations item below a
  copy of the repositories as well, either `restic copy` into a second
  repository (which keeps restic's integrity checks on both copies) or a
  replicated dataset, and extend the verification ladder of the
  [Backups specification](./backups.md) to the copy.
- **Second copy of the media library (2026-10-10)**: the library on
  `rpool-usb-2/media` is a single copy on an aging USB disk, and the previous
  copy died with the raspberrypi2 data disk. Media is replaceable and mostly
  deleted after watching, so restic buys nothing here: use one-way ZFS snapshot
  replication (`zfs send` and `zfs receive`) to a dataset on pve2's `tank-hdd`,
  so deletions propagate and the copy follows the library, with a short snapshot
  retention on the target as the undo for an accidental deletion. Replication
  can only run while pve2 is on: a timer that tolerates an absent target, or the
  pve2 24/7 decision. The evaluation of `tank-hdd` as the long-term media home
  or second copy lives here. Depends on: the pve2 power reduction
  ([Host configuration](#host-configuration)).
- **Nightly file manifest of replaceable media (2026-10-10)**: when the
  raspberrypi2 data disk died, the list of what it held had to be rebuilt from
  the arr and Jellyfin databases, which only cover what those applications had
  scanned, and took hours. Media stays out of restic, but its file list is cheap
  to keep: a timer on the host that mounts the share (hl01, or pve1 against the
  `rpool-usb-2/media` dataset) writes a manifest (path, size, modification time)
  into the host's state directory, which the nightly restic workloads job
  already backs up to a repository on another disk. Complement it with the arr
  and Jellyfin API exports for titles and identifiers. A stack of the node role,
  enabled where a media disk is mounted.
- Back up the Tailscale node state and automate the Samba passwords on the
  Debian hosts, so a re-provisioned host needs neither a manual tailnet re-join
  with route re-approval nor `smbpasswd` runs. Both hold secret material; the
  Samba password automation item ([NAS](#nas)) describes a mechanism that keeps
  it out of the repository.
- Destinations for the second copies:
    - Offsite backup: deploy an offsite host, configure Tailscale, network
      shares, and the backup (repository, schedule, scheduled restic check,
      retention).
    - Cloud backup: cloud sync via Rclone if the provider is not supported by
      restic
      ([VFS caching](https://rclone.org/commands/rclone_mount/#vfs-file-caching)
      to keep retrieval costs down); providers to evaluate: Google Cloud,
      Backblaze, Amazon Glacier, Google Drive; then configure the backup
      (repository, schedule, scheduled restic check, retention).

### NAS

Related specification: [NAS LXC Container](./nas-lxc-container.md).

- **Mirrored vdevs for the ZFS pools (intent recorded 2026-10-18)**: every pool
  declared in `zfs_pools` on pve1 and pve2 is a single-disk vdev, so a disk
  failure loses the pool's contents (the second copies are [Backup](#backup)
  items, and the Syncthing folder on `rpool-usb-1` is itself the copy of the
  remote peer's data). The intended layout is one mirror per pool, which needs a
  second device of at least the same size per pool to protect; `zpool attach`
  turns a single-disk vdev into a mirror in place, after which the pool's
  `zfs_pools` entry records the new topology. The ZFS section of the
  [references page](./references.md#zfs) has the articles behind mirrors over
  RAIDZ.
- **Tailscale on nas-pve1: declarative device management**: manage the joined
  device via the Tailscale Terraform provider, per the
  [operational requirements](./nas-lxc-container.md#135-operational-requirements)
  of the NAS spec: a new Terraform stack (no Proxmox provider, so it runs with
  pve2 off) with `tailscale_device_key` disabling the node's key expiry. Land
  well before the default expiry (about 180 days from the 2026-10-03 join)
  silently takes the backup transport offline.
- **Redeclare the Syncthing GUI settings on the fixed nixpkgs module**: the
  `gui` section and the folder-path default stay imperative at the pinned
  nixpkgs (section-replace semantics and a dead endpoint; the
  [device identity section](./nas-lxc-container.md#124-device-identity-and-state-persistence)
  of the NAS spec records both). The fix is on nixpkgs master but not in
  nixos-26.05, so this needs the next release (expected NixOS 26.11). Once on
  it: redeclare `gui.useTLS`, verify `defaults.folder.path` applies, and confirm
  the imperative GUI credentials survive an activation.
- **Move the Syncthing configuration into a Nix role**: factor the reusable
  parts of the nas-pve1 `services.syncthing` configuration into a role under
  `config/nix/roles/` (shared service defaults in the role, per-host values in
  the host configuration), so a future nas-pve2 instance reuses it.
- **raspberrypi2 restic repository wind-down (decided 2026-09-26)**: hl01's
  repository stays on `rpool-sata` via the existing `backups` share (no
  consolidation onto the USB pools), while raspberrypi2's covers only the
  workloads running there and retires with the host: the backup job keeps
  running until the last workload leaves, and each migrated workload's old
  snapshots can be discarded after about a week of healthy hl01 snapshots (hl01
  picks up a migrated workload's state directory automatically). Since
  2026-10-11 the job writes to a per-host directory on the nas-pve1 `backups`
  share, which retires with the job.
- **NFS support**: re-introduce NFS sharing alongside SMB. Evaluate
  `nfs-kernel-server` in a privileged container versus the user-space
  NFS-Ganesha server, which can run in an unprivileged container.
- **Automated template upload**: replace the local-file push
  (`proxmox_virtual_environment_file` pointing at the local build artifact, per
  the framework pattern) with `proxmox_virtual_environment_download_file`
  pulling the template from a published URL, removing the need for a locally
  built artifact at `terraform apply` time.
- **Samba password automation**: replace the imperative `smbpasswd` step
  ([SMB user management](./nas-lxc-container.md#72-imperative-part-one-time-setup))
  with a mechanism/material split that keeps secrets out of the public
  repository. Design: the `nas` role ships a oneshot systemd unit that, on every
  activation, reads a password file from a well-known path and pipes it into
  `smbpasswd -s -a ferrarimarco`; the Ansible layer that already manages the
  Proxmox nodes writes that file (root-only, `0600`) to
  `/var/lib/samba-state/nas-pveN/smb-password` from a vaulted (untracked)
  variable, so the container's existing `/var/lib/samba` bind mount delivers it.
  Container recreation then self-heals the password database, rotation is an
  Ansible run plus a unit restart, and disaster recovery reduces to the local
  Ansible vault. The same mechanism could deliver the Syncthing sync topology
  and GUI credentials on nas-pve1, which are imperative for the same reason (see
  the NAS spec,
  [device identity and state persistence](./nas-lxc-container.md#124-device-identity-and-state-persistence)).
- **Single source of truth for shares**: derive the Samba share exports (NixOS),
  the bind mounts (Terraform), and the host datasets (Ansible `zfs_datasets`,
  [dataset mount points](./nas-lxc-container.md#111-zfs-dataset-mount-points-on-the-host))
  from one data structure, for example a Nix attrset emitted to `tfvars` via
  `nix eval`, so each share is declared once and the three halves cannot drift
  (see [per-host shares](./nas-lxc-container.md#51-adding-per-host-shares)).

### Documentation

- **Architectural layer model (recorded as an intent on 2026-10-19)**: the
  former architecture overview described the lab as a stack of layers, each with
  its scope:

    ```text
    +---------------------+
    |      Workloads      |
    |---------------------|
    |       Platform      |
    |---------------------|
    |  System | External  |
    |---------------------|
    |      Bootstrap      |
    |---------------------|
    | Hardware management |
    |---------------------|
    |  Physical hardware  |
    +---------------------+
    ```

    - `Workloads`: user-facing applications.
    - `Platform`: the essential components that run the workloads.
    - `External`: external services.
    - `System`: critical system components, such as the hypervisor.
    - `Bootstrap`: automated configuration and deployment processes.
    - `Hardware management`: physical hardware control, such as IPMI, Redfish,
      and KVM.
    - `Physical hardware`: the hardware resources.

    The model separates the concerns the lab has, but nothing follows it yet:
    the configuration tree is split by tool (Ansible, Nix, Terraform), the specs
    index is not grouped by layer, and the hardware management layer has no
    component beyond the `ipmitool` package (BMC power control is an item under
    [Bootstrapping and provisioning](#bootstrapping-and-provisioning)). Adopt
    it, by grouping the specifications index and the todo subsections by layer,
    or discard it.

- Documentation automation: generate the endpoints list, the monitoring checks,
  the inventory, the list of Home Assistant automations, the list of cron jobs,
  and the network plan (the subnet, the lab DNS zone, and the gateway's address
  and name, declared by the node role variables `edge_environment_subnet`,
  `root_dns_zone_fqdn`, and `edge_environment_gateway`; the router-side facts
  stay hand-written in the network stack item under [Networking](#networking))
  from the configuration instead of maintaining them by hand; the hand-written
  network configuration page was dropped on 2026-10-19 because it could only
  drift from those variables.

### Ideas

Undated ideas with no decision and no first step, parked by theme so that the
sections above hold only work. An idea becomes an item when it gets a date and a
first step; software alternatives go to
[Software candidates](./software-candidates.md) instead.

- Bootstrapping and provisioning:
    - Generate a Home Lab bootstrapping keypair.
    - Fully automate Terraform runs
      ([reference](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)),
      with CI for Terraform and the
      [Ansible terraform module](https://docs.ansible.com/ansible/latest/collections/community/general/terraform_module.html#ansible-collections-community-general-terraform-module).
    - Configure the
      [GitHub repositories](https://registry.terraform.io/providers/integrations/github/latest/docs)
      with Terraform.
- Reliability and resilience:
    - Single points of failure to mitigate. Hardware: network gateway, Wi-Fi
      access point, network switches, network cables, power supply units, UPS,
      Zigbee antenna. Software: DHCP server, DNS resolver, MQTT broker,
      Zigbee2MQTT; without an internet connection the Ansible container can't be
      built unless the image is already stored on the host running Ansible.
      Services: WAN.
    - Minimize external dependencies: NixOS ISO server host, Terraform provider
      registry, Docker image registry, Debian package repository, Nix store.
    - Automated troubleshooting playbook: test the DNS server, test the DNS
      resolver.
- Security:
    - Reference container images by hashes.
    - Centralized user management: configure Linux system users, configure
      network shares permissions.
    - Check security vulnerabilities:
      [code scanning](https://github.com/ferrarimarco/home-lab/security/code-scanning),
      [routersploit](https://github.com/threat9/routersploit).
    - Ansible:
      [dev-sec hardening collection](https://github.com/dev-sec/ansible-collection-hardening/).
    - Secure Debian:
      [Securing Debian manual](https://www.debian.org/doc/manuals/securing-debian-manual/index.en.html).
    - Docker: remove users from the Docker group?; Docker socket hardening
      ([Traefik Docker API access](https://doc.traefik.io/traefik/providers/docker/#docker-api-access),
      [docker-socket-proxy](https://github.com/Tecnativa/docker-socket-proxy));
      don't bind ports to every host interface.
    - Block internet access to local-only devices.
    - [Securing Home Assistant](https://www.home-assistant.io/docs/configuration/securing/).
    - [Commit signature verification](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification).
    - qBittorrent: enable HTTPS.
    - Proxmox hardening:
      [against physical attacks](https://dustri.org/b/hardening-proxmox-against-physical-attacks.html),
      [Proxmox VE 9 hardening steps](https://www.virtualizationhowto.com/2025/08/top-security-hardening-steps-for-proxmox-ve-9/).
    - Encrypt disks; unlock remotely:
      [LUKS unlock via Dropbear SSH](https://www.cyberciti.biz/security/how-to-unlock-luks-using-dropbear-ssh-keys-remotely-in-linux/).
    - SSH: sshd AuthorizedKeysCommand; IdentitiesOnly.
- Host configuration:
    - Proxmox cluster (pve1, pve2): configure certificates
      ([certificate management](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#sysadmin_certificate_management),
      [Let's Encrypt](https://www.derekseaman.com/2023/04/proxmox-lets-encrypt-ssl-the-easy-button.html)).
    - Argon One M.2 case: set up logging for the fan controller
      ([firmware updater](https://github.com/Argon40Tech/Argon40case/blob/master/src/argonone-firmwareupdate.py),
      [I2C codes](https://github.com/Argon40Tech/Argon-ONE-i2c-Codes),
      [fan software alternative](https://forum.argon40.com/t/much-better-argon-one-fan-linux-software-alternative/891)).
- Networking:
    - Tailscale exit node: route remote client traffic through the home network
      (for example, from untrusted networks). Separate from the subnet router
      item: an exit node routes the client's internet traffic, not access to the
      LAN.
    - Tailscale: configure SSH; don't accept DNS to avoid depending on Tailscale
      being up?; update the DNS resolver IP address; don't advertise subnet
      routes if there are already unapproved routes for the same node (needs
      [tailscale#5724](https://github.com/tailscale/tailscale/issues/5724)). The
      [references page](./references.md#tailscale) lists the Tailscale articles.
    - DHCP: understand what the dhcp-script does; if staying on dnsmasq, use a
      [Repology](https://docs.renovatebot.com/modules/datasource/repology/)
      source with Renovate to update it.
    - Deploy an ad blocking server; configure block lists for Unbound
      ([StevenBlack/hosts](https://github.com/StevenBlack/hosts)).
    - [Exposing Docker's internal DNS with CoreDNS](https://theorangeone.net/posts/expose-docker-internal-dns/).
    - Store SSH fingerprints as DNS records?
    - DNS rebinding protection: see the dnsmasq "rebind" options.
- Monitoring and alerting:
    - To monitor: EdgeTPU (custom exporter, or
      [edgetpu-exporter](https://github.com/adaptant-labs/edgetpu-exporter));
      CPU C states; CPU vulnerabilities;
      [Docker engine metrics](https://docs.docker.com/engine/daemon/prometheus/);
      the ONT login endpoint (`https://192.168.1.1/login.html`);
      [Tailscale client metrics](https://tailscale.com/blog/client-metrics);
      Prometheus Blackbox monitoring for reverse lookups;
      [Unbound](https://github.com/letsencrypt/unbound_exporter); FlareSolverr;
      HTTPS and TLS certificate validity (ferrarimarco.info, ferrari.how); the
      gateway's dnsmasq DNS queries and DHCP leases
      ([dnsmasq_exporter](https://github.com/google/dnsmasq_exporter)) and
      running processes.
    - Verify the authority section of public resource records.
    - WoL watchdog.
    - Grafana: set a datasource uid to reuse across dashboards; set the unit of
      measurement in the average DNS probe panel; automate updates of the
      provisioned dashboard JSONs (PRs with updates?).
    - Check the [UptimeRobot](https://uptimerobot.com/) configuration.
    - Automate Telegram bot creation.
    - Set up Loki for log aggregation.
- Smart home:
    - Frigate: configure the
      [live view to use the high resolution stream](https://docs.frigate.video/configuration/live#setting-stream-for-live-ui);
      use
      [environment variables](https://docs.frigate.video/configuration/#full-configuration-reference)
      to pass credentials; tune
      [notifications](https://github.com/blakeblackshear/frigate/discussions/559).
    - Smart desk:
      [dimmable LCD display](https://community.home-assistant.io/t/dimmable-pcf8574-lcd-display-with-esphome/272308),
      magnetic contact to signal actuators movement, sensor to ensure that the
      actuators are extended to the same length, actuators that report
      extension, programmable plug for the actuators power source so it can be
      disabled when not needed.
    - Sense HAT:
      [temperature correction](https://github.com/initialstate/wunderground-sensehat/wiki/Part-3.-Sense-HAT-Temperature-Correction).
    - Weather station:
      [Adafruit Wi-Fi weather station](https://learn.adafruit.com/wifi-weather-station-with-tft-display),
      [esp32-weather-epd](https://github.com/lmarzen/esp32-weather-epd).
    - Lock-state sensing for the existing door locks: a Zigbee water-leak sensor
      with an external two-wire probe, hidden in the door frame, with each probe
      wire ending in a foil pad inside the strike box; the thrown deadbolt
      bridges the pads, so "leak" means "locked". Fails safe (any fault reads as
      not locked) and cannot actuate. In Zigbee2MQTT, invert the device's leak
      payload and show the entity as a lock. Constraints: room for the wires in
      the strike box, a conductive deadbolt, and a contact that holds across the
      play of the key.
    - Automations:
        - Smart chair: contact sensor
          ([reference](https://bogdanbujdea.dev/how-i-made-my-chair-smart-with-10dollar)).
        - Closet lighting.
        - Energy: turn the studio power plug off if computers are off.
        - Safety and security: remind people to turn the alarm on when nobody is
          at home; low-battery alerts for smoke detectors and door/window
          sensors; smoke and CO2 alerts to phones and speakers; leak sensors
          with automatic water shut-off if not overridden; arm the alarm when
          everyone is away (motion notifies everyone, turns lights off, closes
          blinds, broadcasts on speakers).
        - Lights: morning wake-up fade-in, nighttime catch-all shutdown, turn
          Hue lights on when main power goes off, night red lights in the
          corridor, holiday lights, motion lights in kitchen and hallways at
          night, dusk-to-armed-night outdoor lights, kids lights-out mode after
          bedtime, bedside all-on/off button, motion plus BLE presence to turn
          lights off, movie mode, all-asleep mode dimming to 1%.
        - Voice commands: control lights.
        - Reminders and announcements: whole-home speaker announcements based on
          calendar events, school pick-up reminder based on presence, commute
          and weather briefing on work days, 17track package notifications (out
          for delivery, delivered).
        - Computers and servers: consumption thresholds (disk, CPU), notify when
          a critical device goes offline, alert if SenseHat readings report 0
          (requires physically power cycling the Raspberry Pi), UPS battery load
          and recharge.
        - Washer and dryer: voice notification when the washing cycle completes.
        - Home theater and TV: "I've got company" scene, one-button
          entertainment center power-on (may need an IR blaster), TV device as
          master power switch, mute speakers when movies play, stop speakers
          after 10 minutes of pause, time-based speaker and Chromecast volume,
          cap speaker volume at 20% on power-off.
        - Kitchen: coffee machine preheating, oven preheat status.
        - Blinds: automate blinds (sunrise/sunset offsets, close on summer sun
          via outside temperature and window lux), close when movies play.
        - Shower: exhaust fan, vanity light, preheat hair tools via smart plugs,
          house lights on, TVs off, curtains closed, heated blanket off.
        - Heating, A/C, and fans: humidity-driven exhaust fans, alert if the
          thermostat is off while heating is on (needs heater state detection),
          open door/window alerts with AC/heater shutdown and restore,
          wrong-mode detection and open-the-windows suggestions, bathroom space
          heater on a smart plug in a closed temperature loop, thermostat
          setpoints per presence, day/time, and alarm state.
        - Windows and doors: open-for-X-minutes phone alerts, leaving-home check
          with presence logic, integration with a whole-house fan.
        - [Zigbee/Z-Wave device notification blueprint](https://www.reddit.com/r/homeassistant/comments/116tk8l/psa_blueprint_to_notify_of_zigbeezwave_devices).
    - Routines:
        - Good-night command: lights and TVs off, doors locked, bedroom fan on.
        - Morning: blinds up and motion lights on a schedule, with snooze
          buttons.
        - Wake-up button: lights, thermostat, coffee maker (only if it has
          water, otherwise announce it).
        - Bedtime button: lights off, thermostat, TV off, doors locked, bedside
          lamp at 10%.
        - Bathroom motion light, fan only above 65% humidity.
        - Night bathroom light at 10% within certain hours.
        - Pressure sensor turns on the TV when sitting down.
        - BLE beacon in the car disarms the alarm on arrival.
        - Door unlock: kitchen lights, thermostat, TV with a welcome
          announcement.
        - Bathroom-door contact sensor locks the outside doors.
        - Start streaming radio when the phone is detected in a zone (work).
        - Occupancy-based automations driven by alarm state instead of
          schedules; doors auto-deadbolt at a set time with a text alert.
        - Phones-charging-after-bedtime trigger: lights off, fan on, delayed TV
          off.
    - Integrations to configure:
        - [ha-smartthinq-sensors](https://github.com/ollo69/ha-smartthinq-sensors)
        - [Syncthing](https://www.home-assistant.io/integrations/syncthing/)
        - [Local to-do](https://www.home-assistant.io/integrations/local_todo)
        - [Google Tasks](https://www.home-assistant.io/integrations/google_tasks)
        - [Feedreader](https://www.home-assistant.io/integrations/feedreader)
        - House map on dashboard
          ([ha-floorplan](https://github.com/ExperienceLovelace/ha-floorplan))
        - Family calendar
        - Toyota MyT
        - Frigate
        - [Backup](https://www.home-assistant.io/integrations/backup/)
        - [Bluetooth tracker](https://www.home-assistant.io/integrations/bluetooth_tracker/)
        - [Bluetooth LE tracker](https://www.home-assistant.io/integrations/bluetooth_le_tracker/)
        - [Certificate expiry](https://www.home-assistant.io/integrations/cert_expiry/):
          ferrari.how
        - [Google Assistant](https://www.home-assistant.io/integrations/google_assistant/)
        - Needs a Google Cloud project:
          [Google Calendars](https://www.home-assistant.io/integrations/google/),
          [Google Pub/Sub](https://www.home-assistant.io/integrations/google_pubsub/)
        - [Cloudflare](https://www.home-assistant.io/integrations/cloudflare/)
        - [Google Maps](https://www.home-assistant.io/integrations/google_maps/)
        - [Google Sheets](https://www.home-assistant.io/integrations/google_sheets)
        - [Google Travel Time](https://www.home-assistant.io/integrations/google_travel_time/)
        - [Energy monitoring](https://www.home-assistant.io/docs/energy/):
          overall consumption, set energy costs,
          [utility meter](https://www.home-assistant.io/integrations/utility_meter)
        - Gas consumption monitoring
        - [Mobile app](https://www.home-assistant.io/integrations/mobile_app/)
        - Water consumption monitoring
        - [Whois](https://www.home-assistant.io/integrations/whois): ferrari.how
          (this TLD is not currently supported)
        - [Speedtest.net](https://www.home-assistant.io/integrations/speedtestdotnet)
    - Dashboard.
- Backup:
    - Cross-host workloads backup, once the destinations exist.
    - Immich to copy data from phones to the NAS.
    - Storage replication: prefer "one-way replication where the direction
      reverses sometimes" over two-way replication, which is harder to
      implement. Filesystem level: ZFS replication.
    - To back up: the Proxmox hosts
      ([pmxcfs](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#chapter_pmxcfs));
      ebooks, comics, and photos, moved to network storage; media (movies,
      shows, ebooks, comics, game saves, software and drivers); with disk
      encryption: passwords, 2 factor authentication secrets, backup access
      codes, Ansible secrets (vault files, the bootstrap public key), ESPHome
      secrets, gateway configuration, photos (RAWs, Lightroom library), GitHub
      (private and public repositories and gists), Google accounts data.
- NAS:
    - Samba performance tuning: benchmark before adding any tuning to the `nas`
      role. Modern Samba enables AIO by default, and the classic knobs interact
      (a non-zero `aio write size` disables `min receivefile size`), so tuning
      without measurement is at best a no-op.
    - SMB service discovery: enable Samba's WS-Discovery or Avahi for automatic
      share browsing on Windows and macOS clients.
- Cloud environment:
    - Configure a cloud environment on Google Cloud: create the resource
      hierarchy.
    - Set quotas to match the caps of the free tier when possible
      ([capping usage](https://cloud.google.com/docs/quota#capping_usage),
      [disable billing to stop usage](https://cloud.google.com/billing/docs/how-to/notify#cap_disable_billing_to_stop_usage)).
