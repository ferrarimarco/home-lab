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

Super-linter writes its results to the gitignored `super-linter-output`
directory in the repository root:

- `super-linter-output/super-linter-summary.md`: the per-linter pass/fail
  summary table. Check this first to see which linters failed.
- `super-linter-output/super-linter/`: the detailed outputs, one
  `super-linter-parallel-stdout-<LINTER>` (and, when produced,
  `super-linter-parallel-stderr-<LINTER>`) file per linter, along with the
  per-linter exit codes and the lists of files each linter processed. Read the
  files for the linters the summary marks as failed to get the actual findings.

Prefer these files over scrolling the console output: they persist after the run
and separate each linter's findings.

`scripts/format.sh` formats the given paths (default: the whole repository) with
the formatters that super-linter validates in check mode, running them from the
same pinned super-linter container image so results match what CI expects:

```shell
scripts/format.sh [path ...]
```

The script runs:

- [Prettier](https://prettier.io/) on Markdown, YAML, JSON, JavaScript, HTML,
  and CSS files, excluding the generated `docs/` site output and the
  `super-linter-output/` directory.
- [markdownlint](https://github.com/DavidAnson/markdownlint) with the repository
  configuration (`config/lint/.markdown-lint.yaml`) on Markdown files. It fails
  when issues that `--fix` cannot resolve remain: fix them manually.
- [shfmt](https://github.com/mvdan/sh) on shell scripts.
- [textlint](https://textlint.org/) with super-linter's default configuration on
  Markdown and text files.
- `terraform fmt -recursive` on Terraform files.

Directories go through every formatter; single files only go through the
formatters that support their file type. Use it as the fast inner loop when
editing: the check-mode `scripts/lint.sh` run remains the authoritative verdict.

The fixers that `scripts/format.sh` covers, and the ones it knowingly delegates
to super-linter fix mode, are listed in `scripts/common.sh`. `scripts/lint.sh`
fails when `config/lint/super-linter-fix-mode.env` enables a fixer that appears
in neither list, forcing a deliberate decision for every new fixer: implement it
in `scripts/format.sh`, or explicitly delegate it.

`scripts/run-pre-commit.sh` runs the configured
[pre-commit](https://pre-commit.com/) hooks
(`config/pre-commit/.pre-commit-config.yaml`) against all files, creating a
dedicated Python virtual environment on first run. Pass an argument to run a
different command inside that environment instead.

## Provisioning and configuration

- `scripts/bootstrap-host.sh <hostname> <expected_mac>`: bootstraps a home lab
  host, validating that the target machine's MAC address matches the expected
  one before deploying. Hosts with a `disko.nix` are installed with
  `nixos-anywhere`; hosts without one (LXC containers) receive their
  configuration via `nixos-rebuild switch --flake --target-host`.
- `scripts/run-ansible.sh`: runs Ansible playbooks from `config/ansible` inside
  a purpose-built container. Select the playbook with
  `ANSIBLE_PLAYBOOK_FILE_NAME` and pass extra flags via
  `ADDITIONAL_ANSIBLE_FLAGS`. To scope a run to one workload stack on one host,
  combine the stack's tag with the `untagged` pseudo-tag (global, untagged
  initialization tasks must always run) and a host limit:

    ```shell
    ADDITIONAL_ANSIBLE_FLAGS="--check --diff --tags='monitoring-apt' --tags untagged --limit raspberrypi2.edge.lab.ferrari.how" \
      ANSIBLE_PLAYBOOK_FILE_NAME="home-lab-node.yaml" \
      scripts/run-ansible.sh
    ```

    Stack tags are the `fact_category` names declared in the
    `ferrarimarco_home_lab_node` role's `include-variables.yaml`. See the
    [Ansible development guide](./ansible.md) for how the role's tagging and
    enablement machinery works.

    Always run with `--check --diff` first and review the predicted changes
    (watching for unexpected `state: absent` teardowns) before repeating the
    same command without those flags to apply.

    The script requires a running SSH agent (`SSH_AUTH_SOCK`) holding the keys
    to connect to the nodes; it forwards the agent socket into the Ansible
    container. Shells that do not inherit the session environment (for example
    AI agent shells) must discover the socket and pass it explicitly: find it
    with `ls /tmp/ssh-*/agent.*`, verify the loaded keys with
    `SSH_AUTH_SOCK=<socket> ssh-add -l`, and prefix the invocation with
    `SSH_AUTH_SOCK=<socket>`. The socket path changes across reboots.

    The script also wraps `ansible-vault` for vault file maintenance: neither
    the host nor the Nix dev shells provide `ansible-vault`. Set
    `ANSIBLE_EDIT_VAULT_FILE=true` to edit a vault file, or
    `ANSIBLE_VIEW_VAULT_FILE=true` to view one read-only. Both modes default to
    `inventory/group_vars/all/vault.yaml`; select a different file with
    `ANSIBLE_VAULT_FILE_PATH` (relative to `config/ansible`). For example, to
    list the key names a vault file defines without exposing secret values:

    ```shell
    ANSIBLE_VIEW_VAULT_FILE=true scripts/run-ansible.sh \
      | grep -oE '^vault[a-zA-Z_0-9-]*'
    ```

    Never print decrypted vault values: pipe `ansible-vault view` output through
    a filter (as above) that only surfaces key names. The filter anchors on the
    `vault` prefix because all vaulted variables follow the `vault_*` naming
    convention, and the script's own log output shares the stream with the
    decrypted content.

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
