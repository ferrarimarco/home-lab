# Container migration

This guide describes how to migrate containerized workloads and their data
between hosts. The migration is driven by the inventory enablement flags and the
repository's operational scripts: there is deliberately no migration playbook or
script, because migrations are rare and their risky parts (capacity, stateful
cutover, hardware dependencies) need case-by-case review.

## Before starting

1. **Check capacity before copying anything**: measure the source directories
   with `du -s` and compare against `df` of the target filesystem, leaving
   growth headroom. A migration plan can be invalidated entirely by a target
   share smaller than the data set, and an rsync run that discovers this
   mid-copy leaves a half-filled target to clean up.
2. **Verify recent restic workload backups exist** for the stack being migrated:
   the backed-up configuration and state directories are the rollback safety net
   if the cutover goes wrong.
3. **Identify hardware dependencies** (USB devices such as Zigbee adapters or
   Coral accelerators): these need a physical move and, when the target is a
   virtual machine, a hypervisor passthrough change before the workload can
   start on the target host.

## Procedure

1. Set the `configure_rsync_daemon` variable for the target host to `true` to
   set up an rsync daemon.
1. Initialize the `rsync_daemon_modules` variable for the target host to
   configure rsync modules.
1. Set the `configure_xxxxx` variable for the target host to `true` to prepare
   the target host.
1. Set the `start_xxxxx` variable for the target host to `false` because we
   don't want to start any services before copying data.
1. Run Ansible. With the above configuration, it will prepare the target host
   without starting any service.
1. Set the `start_xxxxx` variable for the source host to `false` to stop the
   service we're migrating.
1. Run Ansible. Stopping the source services before copying is mandatory for
   stateful workloads: their state databases (typically SQLite) must be
   quiesced, because copying them while the services run risks a corrupted copy.
1. Copy the data directories AND the untracked configuration and state
   directories (under `/etc/ferrarimarco-home-lab/<service>`) from the source
   host to the target host with `scripts/copy-data.sh`, running each copy with
   `ENABLE_DRY_RUN=true` first. Files that Ansible renders from templates (for
   example `compose.yaml` files or `qBittorrent.conf`) need no copying: the next
   Ansible run re-renders them on the target.
1. Remove the `start_xxxxx` from the target host configuration because it
   defaults to the `configure_xxxxx` value, which is set to `true`.
1. Update endpoint definitions in
   `config/ansible/inventory/group_vars/all/main.yaml` (the `*_endpoint_fqdn`
   variables) so monitoring probes and cross-host references point at the target
   host.
1. Run Ansible.
1. Verify that the containers work in the target environment as expected:
   service health, application state present (libraries, histories, settings),
   and clean logs. Re-check any credential or token the copied state carries
   against the target's services.
1. Remove the `start_xxxxx` variable from the source host configuration.
1. Remove the `configure_xxxxx` variable from the source host configuration.
1. Run Ansible. This will remove all the copied data from the source host.
1. Delete data in the source host if it's not deleted automatically, such as
   media directories.
1. If not needed anymore, disable the rsync daemon by removing the
   `configure_rsync_daemon` and `rsync_daemon_modules` variables in the target
   host configuration.
1. Commit the changes in the repository.

## Data migration examples

These examples assume that the current working directory is the root of this
repository:

- Copy one directory from one host to another by connecting an rsync daemon
  running on the target host:

    ```sh
    scripts/copy-data.sh "user@source.host" "/source/directory" "rsync://rsync_user@target.host/destination/directory"
    ```

- Copy one directory from one host to another using rsync:

    ```sh
    scripts/copy-data.sh "user@source.host" "/source/directory" "user@target.host:/destination/directory/"
    ```
