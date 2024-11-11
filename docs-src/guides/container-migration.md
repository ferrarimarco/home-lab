# Container migration playbook

If you need to migrate containers and data between hosts, do the following:

1. Set the `configure_xxxxx` variable for the target host to `true` to prepare the target host.
1. Set the `start_xxxxx` variable for the target host to `false` because we don't want to start any services
   before copying data.
1. Run Ansible. With the above configuration, it will prepare the target host without starting any service.
1. Set the `start_xxxxx` variable for the source host to `false` to stop the service we're migrating.
1. Run Ansible.
1. Copy data from the source host to the target host. You can use `scripts/migrate-container-data.sh` script to transfer data from
   one host to another.
1. Remove the `start_xxxxx` from the target host configuration because it defaults to the `configure_xxxxx` value, which is set to `true`.
1. Run Ansible.
1. Remove the `start_xxxxx` variable from the source host configuration.
1. Remove the `configure_xxxxx` variable from the source host configuration.
1. Run Ansible.
1. Commit the changes in the repository.

## Data migration examples

These examples assume that the current working directory is the root of this repository.

To migrate one directory from one host to another:

```sh
scripts/migrate-container-data.sh "user@source.host" "/source/directory" "user2@target.host" "/destination"
```
