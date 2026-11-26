# Linux administration notes

## Reach the hosts

Connect over SSH using each host's fully qualified domain name as the Ansible
inventory lists it (`<host>.edge.lab.ferrari.how`): the short hostnames do not
resolve from the control machine. Log in as `root` on the Proxmox nodes, as
`debian` on the hl01 VM, as `pi` on raspberrypi2, and as the administrative user
of the `common` Nix role on the NixOS hosts. hl01 has no Zsh: wrap a multi-step
remote command in `bash -ec '...'`.

The gateway router accepts the lab key too, on a port and as a user that are
vault values (`vault_asuswrt_administration_ssh_port` and
`vault_asuswrt_administrator_username`): take them from a playbook log or a
rendered unit, and keep them out of replies and committed files. Prefer the
`gateway-dnsmasq.yaml` playbook, which the
[Ansible development guide](../development/ansible.md) describes together with
the reason to keep commands on the router short and the shell's quirks. The
router's host key gets the same treatment as any other host's; to read it
without logging in, use `ssh-keyscan`, since a connection offers every key the
agent holds and the lab key is authorized there.

Failed logins trip the router's login protection: a `DROP` rule for the source
address appears in the `PTCSRVLAN` chain and that host's connections time out
instead of being refused, while `dropbear` logs the attempts in
`/tmp/syslog.log` ("Bad password attempt" when the offered key is rejected and
the client falls back to a password). Read the chain from a host that is not
blocked (`iptables -S PTCSRVLAN`) or the router's web interface; fix what the
blocked host offers first (its key on the router's authorized keys), since a
retry with the bad key re-arms the block, which was observed to expire about
hourly on its own.

A first connection to a host from a machine fails under `BatchMode=yes` with
"Host key verification failed", the line a changed key's output also ends with.
Tell the two apart before accepting anything: `ssh-keygen -F <fqdn>` (the name
as SSH stored it; `-f` selects a known hosts file other than
`~/.ssh/known_hosts`) prints nothing for a host that file never saw, and an
entry for a mismatch. For an unknown host, connect once with
`-o StrictHostKeyChecking=accept-new`; for a mismatch, find out why the key
changed before touching the known hosts file.

A host whose key was accepted under another name (its short hostname, an
address) is still unknown under the name in use. Compare the stored key with the
one the host offers (`ssh-keygen -F <other name>` against `ssh-keyscan <fqdn>`),
and record it with `accept-new` when they match.

## Debian

### OS package management

- Get the versions that are available to install of a package:
  `apt-cache madison <package-name>`
- Install a specific package version:
  `apt-get install <package-name>=<package-version-number>`
- The package update logs are in `/var/log/apt/history.log`

### OS package upgrade

One run of the OS packages playbook upgrades a Debian host, reboots it when its
reboot-required flag is set, and verifies it, as the
[OS package upgrades spec](../../architecture/os-package-upgrades.md) describes;
its status table says which parts a real host has run. The NixOS hosts upgrade
through their flake. The `AptUpgradesPending` and `RebootRequired` alerts are
what asks for a run.

1. Review with a check run, limited to the host or, without the limit, on every
   Debian host that is on (a host that is off ends the run), with the output in
   a log outside the repository:

    ```shell
    ADDITIONAL_ANSIBLE_FLAGS="--check --diff --limit <host>" \
      ANSIBLE_PLAYBOOK_FILE_NAME="update-os-packages.yaml" \
      scripts/run-ansible.sh > <log file> 2>&1
    ```

    Read three things in it: apt's plan, in the diff of the dist-upgrade task;
    the verdict of the removal guard, a failure that a check run reports and
    ignores, with the `-e` argument that approves the removals it names; and the
    task that reports the reboot-required flag, with the kernel packages of the
    plan.

2. Decide the moment. The real run reboots the host when its flag is set after
   the upgrade, with no option to skip it: that is the case when the check run
   shows the flag set or a kernel in the plan. The reboot takes the host down
   and, on a Proxmox node, its guests, and the probe alerts of the whole lab are
   silenced until the host is verified, for an hour at most.
3. Run the same command without `--check --diff`. A run that approves removals
   takes one host (`--limit <host>` and the `-e` argument of the check run,
   quoted as the
   [operational scripts guide](../development/operational-scripts.md) describes
   for extra variables). A run on several hosts takes them one at a time and
   stops at the first one that fails.
4. Read a failure by its task. Every failure after the reboot leaves the host
   upgraded and rebooted, with the silences on its instances and on the probe
   alerts expired, so whatever is broken notifies; a second run does not repeat
   the verification, since the flag is gone.
    - No monitoring replica answers: nothing was silenced or rebooted, and the
      flag stays set. Check Alertmanager on the replicas, as the
      [monitoring guide](./monitoring.md#alerting) describes, and run again.
    - The host does not answer within the reboot timeout: follow the
      [unresponsive host guide](./unresponsive-host.md).
    - The boot did not finish, or a unit is in the failed state: the failure
      prints the state or the units.
    - A guest or a pool of a Proxmox node is not back: the failure names them;
      the [Proxmox administration notes](./proxmox.md) cover a guest that failed
      its boot-time start.
    - The silences hide an alert that was not active before: the failure names
      it with its labels.
    - The host still runs its old kernel although the flag named a newer one:
      the failure names the kernels. On a Raspberry Pi, check that the firmware
      package that copies the kernel to the boot partition is installed.
5. After a run that died (the control machine went away, or the host could not
   be reached after its reboot), the silences end on their own within their
   duration. List the ones the run added, whose author is `update-os-packages`,
   and expire them by ID to hear the alerts sooner, with the commands of the
   [monitoring guide](./monitoring.md#planned-downtime).

The dist-upgrade task runs detached from the SSH session, so a dropped
connection does not interrupt it. The controller can still lose the job (its
worker died a minute into hl01's release upgrade, and the play kept polling
without reaching the host; on pve1 on 2026-11-26 the upgrade ended on the host
at 10:07:38 UTC, 53 seconds after it restarted `pve-cluster`, and the play only
went on at 10:15:31): the host-side run is then read from the apt history log
and from the job's result file under `/root/.ansible_async/`, and the playbook
is run again once apt is idle, which finishes whatever remains, the reboot
included.

### Release upgrade

The playbooks upgrade a Debian host in place to the next release; the host keeps
its state trees and its container images, and the upgrade costs one reboot. A
fresh install (a VM rebuilt from a cloud image, a re-imaged Raspberry Pi)
follows the fresh host procedure of the [backup operations guide](./backup.md)
instead.

1. Read the host: `apt-mark showhold` (nothing held), the packages installed
   from backports or third-party repositories (`apt list --installed`, the
   release notes of the new release say which are known to break), and the free
   space on the root filesystem (the upgrade needs a few gigabytes).
2. Secure the pre-change copy: run the host's backup job by hand and confirm its
   snapshot, and for a VM snapshot its root volume on the node
   (`zfs snapshot rpool/data/vm-<id>-disk-<n>@pre-<release>`), the rollback for
   a broken upgrade (`zfs rollback` with the VM stopped). The run of step 4 adds
   the silences for its reboot.
3. Point APT at the new release through the bootstrap playbook, which renders
   the Debian sources from `debian_release_force_upgrade` instead of the running
   release, check run first:

    ```shell
    ADDITIONAL_ANSIBLE_FLAGS="--check --diff --limit <host> -e debian_release_force_upgrade=<codename>" \
      ANSIBLE_PLAYBOOK_FILE_NAME="bootstrap.yaml" scripts/run-ansible.sh
    ```

    Third-party sources (Docker's) keep the old release name until their role
    runs on the upgraded host; their packages for the old release install on the
    new one in the meantime.

4. Upgrade with the [OS package upgrade](#os-package-upgrade) procedure, limited
   to the host. Its check run predicts the upgrade, and the removals need a
   review: a package the new release drops takes its dependents with it, the
   removal guard fails on them, and it prints the `-e` argument that names them
   all. The real run, with that argument, keeps the existing configuration files
   where the new packages ship changed defaults (the new files land beside them
   with a `.dpkg-dist` suffix); the new kernel sets the reboot-required flag, so
   the run goes on to reboot and verify the host. The package run itself took
   three minutes on hl01 for 411 upgraded, 129 new, and 65 removed packages.

    The builds of the out-of-tree kernel modules (DKMS) run during the kernel
    install and fail there, not at boot: a failed build fails the kernel
    package's post-install hook, apt stops with the kernel and headers
    unconfigured, and the run fails at its upgrade task, before any reboot. Fix
    the module source (on hl01 on 2026-11-04, the Coral driver source predated
    the pinned package and lacked the fixes for kernel 6.12: `dpkg -i` of the
    pinned file unpacked the right source and exited non-zero because the
    headers were still unconfigured, which is expected at that point), then
    `dpkg --configure -a` configures the pending packages, the module among
    them, and runs the hook again. Run the playbook again afterwards: it
    finishes whatever remains, the reboot included.

5. Verify what the run does not: the release in `/etc/os-release`, the mounts,
   and the out-of-tree kernel modules (`dkms status`).
6. Converge on the new release: the container engine playbook moves the Docker
   source to the new release, and the node playbook surfaces whatever the
   release changed under the roles, check runs first.

## Networking

- Get the list of open ports on a system (with superuser privileges, it also
  returns process information): `sudo netstat -nlp`

## Disks, partitions, and filesystems

- Get the list of block devices: `lsblk`
- Get the attributes of a block device: `blkid <device>`
- Get the list of disks and partitions and add the partition UUID:
  `lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,PARTUUID`
