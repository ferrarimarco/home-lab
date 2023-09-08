# Container migration playbook

If you need to migrate containers and data between hosts, do the following:

1. Set the `configure_xxxxx` variable for the target host to `true` to prepare the target host.
2. Set the `configure_xxxxx_dns_records` variable for the target host to `false` because we don't (likely)
    want to update the DNS zone yet.
3. Set the `start_xxxxx` variable for the target host to `false` because we don't want to start any services
    before copying data.
4. Run Ansible. With the above configuration, it will prepare the target host without starting any service.
5. Set the `stop_xxxxx` variable for the source host to `true` to stop the service we're migrating.
6. Run Ansible.
7. Copy data from the source host to the target host. You can use `scripts/migrate-data.sh` script to transfer data from
    one host to another.
8. Remove the `configure_xxxxx_dns_records` from the target host configuration because it defaults to the `configure_xxxxx` value, which is set to `true`.
9. Remove the `start_xxxxx` from the target host configuration because it defaults to the `configure_xxxxx` value, which is set to `true`.
10. Set the `configure_xxxxx_dns_records` from the source host configuration to `false`.
11. Run Ansible.
12. Remove the `stop_xxxxx` variable from the source host configuration.
13. Remove the `configure_xxxxx_dns_records` variable from the source host configuration.
14. Remove the `configure_xxxxx` variable from the source host configuration.
15. Run Ansible.
16. Commit the changes in the repository.

## Data migration examples

These examples assume that the current working directory is the root of this repository.

To migrate one directory from one host to another:

```sh
scripts/migrate-container-data.sh "user@source.host" "/source/directory" "user2@target.host" "/destination"
```
