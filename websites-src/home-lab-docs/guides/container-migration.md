# Container migration playbook

If you need to migrate containers and data between hosts, do the following:

1. Set the `configure_rsync_daemon` variable for the target host to `true` to
   setup an rsync daemon.
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
1. Run Ansible.
1. Copy data from the source host to the target host. You can use
   `scripts/copy-data.sh` script to copy data from one host to another.
1. Remove the `start_xxxxx` from the target host configuration because it
   defaults to the `configure_xxxxx` value, which is set to `true`.
1. If needed, update endpoint definitions in
   `config/ansible/inventory/group_vars/all/main.yaml`.
1. Run Ansible.
1. Verify that the container works in the target environment as expected.
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
