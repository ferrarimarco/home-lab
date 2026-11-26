# Nix development

## Run host integration tests

Every host directory under `config/nix/hosts/` with a `default.nix` is
automatically registered as a flake check named `host-<host>-test` (see the
[Declarative Integration Testing specification](../../architecture/declarative-integration-testing.md)).
Run one host's test locally from the repository root with:

```shell
nix build ./config/nix#checks.x86_64-linux.host-<host>-test --no-link -L
```

Keep these points in mind:

- Nix flakes evaluate only Git-tracked files: `git add` newly created files (for
  example a new role directory) before building, or evaluation fails with a "not
  tracked by Git" error.
- Pass `--no-link` so the build does not clobber the repository's single
  `result` symlink, which the `220-proxmox-workloads` Terraform stack reads for
  staged image artifacts.
- When writing test script assertions, remember that `machine.succeed` runs
  commands under `pipefail`: an early-exiting pipe consumer such as `grep -q`
  closes the pipe while the producer is still writing large output, failing the
  pipeline with the producer's write error. Use a consumer that reads the full
  stream (for example `grep <pattern> > /dev/null`).

## Open a Python shell in a test virtual machine

1. Start the interactive test driver:

    ```shell
    nix run .#checks.x86_64-linux.<machine-name>-test.driverInteractive
    ```

    To exit the test driver, use the `CTRL-d` key combination.

1. Start all machines:

    ```python
    start_all()
    ```

1. Open a Linux shell:

    ```python
    machine.shell_interact()
    ```

## Nix GitOps

Nix machines run [comin](https://github.com/nlewo/comin) to implement GitOps.

Pushing commits to branches named `testing-<host-name>` makes comin pull
changes, apply them, but not update the bootloader to boot from the newly
generated configuration. Comin updates the bootloader when commits are pushed to
the default branch. For more info, see
[Comin how-tos](https://github.com/nlewo/comin/blob/main/docs/howtos.md).

If the default branch changes, update `config/nix/roles/comin/default.nix`
accordingly.

## Upgrade to a new NixOS release

A release upgrade moves the `nixpkgs` input of the flake to the next release
branch, one release at a time. `system.stateVersion` stays at its value: it
records the release whose on-disk layouts a host's data was created with, and
modules read it to keep those layouts, so raising it upgrades nothing.

1. Read the "Backward Incompatibilities" section of the release notes against
   the services the hosts run, and evaluate the flake on the new release before
   editing anything, from `config/nix`:

    ```shell
    nix flake check --no-build --keep-going --no-write-lock-file \
      --override-input nixpkgs github:NixOS/nixpkgs/nixos-<release>
    ```

    Run the same command without the override first, as the baseline: the
    `minimal-iso` and `minimal-lxc` configurations fail the bootable-system
    assertions on any release, and `--no-build` fails the hl02 test with "path
    ... is not valid" while the mock image it imports is not in the store
    (`nix eval --raw .#checks.x86_64-linux.host-hl02-test.drvPath` evaluates it
    with the build allowed).

1. Change the release in `config/nix/flake.nix`, update that input alone
   (`nix flake update nixpkgs --flake ./config/nix`), then build one host's
   system and compare it with the one it replaces:

    ```shell
    nix build ./config/nix#nixosConfigurations.<host>.config.system.build.toplevel \
      --no-link --print-out-paths
    nix store diff-closures <running system> <new system>
    ```

    The running system is the target of `/run/current-system` on the host. The
    committed tree builds to the same store path, so the comparison needs no
    copy from the host, and the difference lists every version that moves and
    its download size.

1. Open a pull request: its checks build every host and run the host integration
   tests, which boot each system from scratch on the new release. The head
   branch can be the comin testing branch of one host (`testing-<host>`, cut
   from the remote default branch), which then activates the commit in test mode
   while the checks run; restarting that host returns it to its previous system.
1. Silence the alerts of the hosts as the
   [monitoring guide](../operations/monitoring.md) describes, and push to the
   default branch. comin on each host builds the system and runs
   `switch-to-configuration switch`, which writes the boot entry first and then
   activates the system in place. It does not restart the host.
1. Read each host's switch output (`journalctl -u comin.service`) and confirm
   which system the host boots next: the default entry of `bootctl list` on a
   VM, the `exec` line of `/sbin/init` in a container.
1. Restart each host from its Proxmox node (`qm reboot <id>`,
   `pct reboot <id>`), which does not depend on the state of the guest, and
   verify it: the running and booted systems, the failed units, the errors of
   the boot (`journalctl -b -p err`), and the services through their consumers.

### What comin does with a change that needs a restart

- comin deploys the default branch with `switch` and never restarts a host.
  `comin status` prints "Need to reboot: yes", and the exporter sets
  `comin_need_to_reboot`, when the kernel of the running system differs from the
  booted one. A container has no kernel of its own, so neither reports anything
  there.
- From NixOS 26.05, a system lists its switch inhibitors in a
  `switch-inhibitors` file (`system.switch.inhibitors`), and
  `switch-to-configuration` refuses a `switch` or a `test` when a value differs
  between the running system and the new one. comin at the pinned revision reads
  the same two files and deploys such a change with `boot` instead of `switch`
  (and skips a `test`), then reports that a reboot is needed until the host runs
  that system, on a container too. This is from its source: no deployment in
  this lab has taken that path yet. A running system without the file inhibits
  nothing, which is the case of every system built from 25.11.
- A failed switch is not retried. The alert gauge `comin_last_deployment_failed`
  returns to 0 when comin restarts, while `comin status` and
  `comin_deployment_info` keep the failed record until the next deployment that
  changes the host.

### The upgrade from 25.11 to 26.05

Applied on 2026-11-26 to hl02, nas-pve1, and nas-pve2, with no change to the
configuration. What the run showed:

- 26.05 replaces the classic D-Bus daemon with dbus-broker, a change that needs
  a restart, and the switch from 25.11 runs in place because 25.11 has no switch
  inhibitors. systemd then asks the running daemon to reload in the way
  dbus-broker does, gets no answer, and gives up after 90 seconds ("Reload
  failed for D-Bus System Message Bus"). `switch-to-configuration` exits with
  status 4 and comin records a failed deployment, while every other unit is
  stopped and started as usual and the bus keeps answering.
- The restart brings up dbus-broker. On hl02 it is also the first boot on the
  new kernel and on the initrd based on systemd, the default from 26.05.
- nas-pve2 was the canary: its test activation failed in the same way, and its
  later switch from the default branch succeeded, since the reload had already
  been attempted.
- Syncthing migrated its databases on its first start on the new version, so a
  return to the previous system needs a copy of its state taken before the
  switch. Proxmox cannot snapshot a container with bind mount points
  (`pvesh get /nodes/<node>/lxc/<id>/feature --feature snapshot` reports
  `hasFeature: 0`): the copy is a ZFS snapshot of the container's root dataset
  and of the node dataset that holds the state directories. This run took none.

## Nix commands

- `nix flake metadata <path>`: show flake metadata
- `nix flake show <path>`: show information about the flake
- `nix fmt . -- --clear-cache`: format the Nix codebase
- `nix build .#checks.x86_64-linux.lint-treefmt-nix --verbose`: run linting and
  formatting checks
- `nixos-rebuild switch --flake ".#<host>" --target-host "<ssh-user>@<host>" --sudo`:
  apply changes to host when it's not running comin.
- `nix flake check <path>`: run all flake checks
- `nix build <path>#checks.<check-name>`: run a specific check
- `nix build <path>#<package-name>`: build specific package
    - `nix build --rebuild <path>#<package-name>`: rebuild a package
    - `nix build --print-build-logs <path>#<package-name>`: print build log
- `nix-store --gc`: clean the Nix store
