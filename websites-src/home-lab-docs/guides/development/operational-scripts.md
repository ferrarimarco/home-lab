# Operational scripts

This document describes the operational scripts in the
[`scripts`](https://github.com/ferrarimarco/home-lab/tree/master/scripts)
directory. These scripts support developing, validating, provisioning, and
maintaining the home lab.

Run every script from the repository root: the scripts source
`scripts/common.sh` and resolve configuration files using paths relative to the
repository root. Most scripts wrap containerized tools, so they require a
working Docker installation.

## Linting and formatting

`scripts/lint.sh` runs
[super-linter](https://github.com/super-linter/super-linter) against the whole
repository, using the same container image version and configuration as the
`Lint` CI workflow (`.github/workflows/lint.yaml` and
`config/lint/super-linter.env`), so a clean local run closely predicts a clean
CI run:

```shell
scripts/lint.sh
```

The script supports the following environment variables:

- `LINTER_CONTAINER_FIX_MODE`: set to `true` to run the linters in fix mode
  (loads `config/lint/super-linter-fix-mode.env`), letting formatters apply
  fixes to the working tree instead of only reporting issues:

    ```shell
    LINTER_CONTAINER_FIX_MODE=true scripts/lint.sh
    ```

- `LINTER_CONTAINER_OPEN_SHELL`: set to `true` to open an interactive Bash shell
  inside the linter container instead of running the linters, useful to debug
  linter configuration.
- `LINTER_CONTAINER_IMAGE_VERSION`: override the linter container image version.
  Defaults to the version that the `Lint` CI workflow pins.
- `LOG_LEVEL`: super-linter log level. Defaults to `INFO`.

`scripts/run-pre-commit.sh` runs the configured
[pre-commit](https://pre-commit.com/) hooks
(`config/pre-commit/.pre-commit-config.yaml`) against all files, creating a
dedicated Python virtual environment on first run. Pass an argument to run a
different command inside that environment instead.

## Provisioning and configuration

- `scripts/bootstrap-host.sh <hostname> <expected_mac>`: bootstraps a home lab
  host, validating that the target machine's MAC address matches the expected
  one before installing.
- `scripts/run-ansible.sh`: runs Ansible playbooks from `config/ansible` inside
  a purpose-built container.
- `scripts/run-terraform.sh`: iterates over the numbered Terraform service
  directories in `config/terraform` and runs `terraform init` and
  `terraform apply` for each one. Run
  `scripts/run-terraform.sh output <service> [<output-name>]` to print a
  service's outputs as JSON instead.

## Documentation site

`scripts/run-mkdocs.sh` builds or serves the documentation sites with Material
for MkDocs. See [Develop and build the Home Lab site](./website-development.md).

## CI/CD tooling

- `scripts/open-shell-ci-cd-tools-container.sh`: opens an interactive shell in
  the CI/CD tools container (`docker/ci-cd-tools`).
- `scripts/release-please-dry-run.sh`: runs a release-please `release-pr` dry
  run against the current branch to preview release notes and version bumps.
- `scripts/run-renovate.sh`: runs Renovate locally.

## Miscellaneous

- `scripts/build-arduino-project.sh`: compiles an Arduino project for a given
  fully qualified board name (FQBN).
- `scripts/copy-data.sh <source-host> <source-directory> <target-directory>`:
  copies data from a remote host with rsync. Set `ENABLE_DRY_RUN=true` for a dry
  run and `ENABLE_CHECKSUM=true` to compare files by checksum.
- `scripts/common.sh`: shared helper functions and variables sourced by the
  other scripts; not meant to be invoked directly.
