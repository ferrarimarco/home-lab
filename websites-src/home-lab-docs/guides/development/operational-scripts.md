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

The script also runs from a
[Git worktree](https://git-scm.com/docs/git-worktree): a worktree holds only the
working files, so the script mounts the main repository's metadata directory
into the container at the same absolute path, as the
[super-linter local run documentation](https://github.com/super-linter/super-linter/blob/main/docs/run-linter-locally.md)
describes.

The run covers the committed tree only, by configuration:
`config/lint/super-linter.env` sets `VALIDATE_ALL_CODEBASE=true` and leaves
`USE_FIND_ALGORITHM` at its default, so super-linter lists the files with
`git ls-tree -r HEAD`, and staging or `git add --intent-to-add` changes nothing
(a new file passed two lint runs untracked and failed its first run once
committed, 2026-10-21). Commit a new file first, lint, and amend; the
alternative is the find-based listing (`USE_FIND_ALGORITHM=true`), which walks
the working tree.

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
- `LINTER_CONTAINER_LINT_COMMIT_MESSAGE`: set to `true` to validate a commit
  message from the standard input instead of running the linters, with the same
  configuration (`commitlint.config.js`) and strictness as the lint run:

    ```shell
    LINTER_CONTAINER_LINT_COMMIT_MESSAGE=true scripts/lint.sh < <message file>
    ```

    Validate commit messages before committing: the lint run only validates the
    message of the last commit, while the `Lint` CI workflow validates the
    messages of all the pushed commits. You can run this check while a lint run
    is in progress.

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

The linter container runs as `root` and rewrites the Git index (`.git/index`),
which then belongs to `root`. A lint run can also unstage staged changes, so
stage files after linting, right before committing. Committing still works
because Git replaces the index file instead of writing to it.

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
  configuration (`config/lint/.markdown-lint.yaml`) on Markdown files. Issues
  that `--fix` cannot resolve do not stop the run: the ones Prettier fixes (for
  example, table pipe alignment) are cleared by a second markdownlint pass that
  runs after the other formatters, and the script fails only when that pass
  still reports issues — those need manual fixes.
- [shfmt](https://github.com/mvdan/sh) on shell scripts.
- [textlint](https://textlint.org/) with super-linter's default configuration on
  Markdown and text files.
- `terraform fmt -recursive` on Terraform files.

The script runs textlint and markdownlint before Prettier, so that Prettier
formats the results of their fixes.

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

## Testing

- `test/scripts/prometheus-rules-test.sh`: validates the Prometheus alerting
  rule file with `promtool check rules` and runs the rule unit tests under
  `test/prometheus-rules/` with `promtool test rules`, from the Prometheus
  container image the monitoring backend runs: the `prometheus` stage of the
  dependency updates helper Dockerfile, the single pin that Dependabot bumps and
  the node role renders into the compose files. The `Test Prometheus rules` CI
  workflow runs it on every change to the rules, the tests, the script, or the
  pin. The tests hold one file per rule group, and every rule has a firing case
  asserting its labels and annotations, and a non-firing case (below the
  threshold, or before the `for` duration elapses). The script enforces both
  before running promtool: it fails, naming the rules, when a rule has no test
  case, when a test names a rule the file does not define, or when a rule has no
  case with `exp_alerts: []`. Conventions, verified against promtool 3.15.0:
    - `rule_files` paths resolve relative to the test file, not to the working
      directory.
    - Keep `evaluation_interval: 1m`, the deployed Prometheus value: a `for`
      duration is counted in rule evaluations at that interval, while the
      per-group `interval` only spaces the input samples (groups with 30 s, 2 m,
      and 5 m intervals all fired a `for: 10m` rule at 10 minutes). Keep the
      sample interval within the 5 minute lookback for rules with a `for`
      clause, or the series goes stale between samples and the pending alert
      resets (6 m and 10 m intervals never fired it); rules without one may use
      coarser samples evaluated at sample timestamps.
    - `AxN` in `values` emits N+1 samples (the value, then N repeats), so a
      transition written as `0x2 1x2` happens at the third sample, not the
      second.
    - The test clock starts at the Unix epoch, so staleness rules built on
      `time()` take a sample value of `0` and an `eval_time` equal to the age to
      test.
    - `exp_annotations` must match the rendered annotations exactly, with the
      `>-` folded descriptions on one line, and `{{ $value }}` renders the
      evaluated number. `increase()` and `delta()` extrapolate to the range
      boundaries, so a counter that steps from 0 renders an integer (the start
      extrapolation is capped at zero) while one that steps from a non-zero
      baseline renders a long float: start such counters at 0, or keep `$value`
      out of the assertion.
- `test/scripts/build-python-venv-test.sh [requirements file]`: runs the node
  role's `build-python-venv.sh` script twice against a temporary directory to
  check that it builds a virtual environment from a requirements file and skips
  an up-to-date one; the `Test shell scripts` and
  `Test Python requirements files` CI workflows run it.

## Provisioning and configuration

`scripts/bootstrap-host.sh` and `scripts/run-terraform.sh` depend on tools that
only the `operations` Nix development shell provides, so run them inside that
shell. See the [Nix development shells guide](./nix-dev-shells.md).

- `scripts/bootstrap-host.sh <hostname> <expected_mac>`: bootstraps a home lab
  host, validating that the target machine's MAC address matches the expected
  one before deploying. Hosts with a `disko.nix` are installed with
  `nixos-anywhere`; hosts without one (LXC containers) receive their
  configuration via `nixos-rebuild switch --flake --target-host`.
- `scripts/run-ansible.sh`: runs Ansible playbooks from `config/ansible` inside
  a purpose-built container. Select the playbook with
  `ANSIBLE_PLAYBOOK_FILE_NAME` and pass extra flags via
  `ADDITIONAL_ANSIBLE_FLAGS`. Pick the narrowest playbook for the change first:
  per-purpose playbooks under `config/ansible/playbooks/` exist alongside
  `home-lab-node.yaml`; `restore-workloads.yaml` restores a stack's state from a
  restic repository and is documented in the
  [backup operations guide](../operations/backup.md). The others (for example,
  `setup-disks.yaml` converges pools, datasets, mounts, and the
  `directories_to_create` list), and `main.yaml` chains all the playbooks, so
  tag-scoping it also runs the untagged tasks of every other role — on a host
  outside those roles' normal scope, the check run then predicts unrelated,
  possibly destructive changes. To scope a run to one workload stack on one
  host, combine the stack's tag with the `untagged` pseudo-tag (global, untagged
  initialization tasks must always run) and a host limit:

    ```shell
    ADDITIONAL_ANSIBLE_FLAGS="--check --diff --tags='monitoring-apt' --tags untagged --limit raspberrypi2.edge.lab.ferrari.how" \
      ANSIBLE_PLAYBOOK_FILE_NAME="home-lab-node.yaml" \
      scripts/run-ansible.sh
    ```

    Restic repositories are initialized by the node role's read-then-act task
    only, never by the backup job: the task runs `restic init` through the job
    container with `RESTIC_ALLOW_INIT=true` when the repository's `config` file
    is absent and `findmnt --target` shows the repository path backed by a
    filesystem other than the root one; the job's unit refuses to run on the
    root filesystem for the same reason, and the entrypoint refuses an implicit
    initialization. A replacement host whose repository already exists on the
    share is therefore never re-initialized.

    Stack tags are the `fact_category` names declared in the
    `ferrarimarco_home_lab_node` role's `include-variables.yaml`. See the
    [Ansible development guide](./ansible.md) for how the role's tagging and
    enablement machinery works. The Docker Compose lifecycle tasks (image pulls,
    service starts, and the restarts that configuration changes trigger) carry
    the `always` tag so tag-scoped runs still execute them — their
    `molecule-notest` tag alone would deselect them, deploying changed
    configuration without restarting the services that read it; Molecule still
    skips them via `--skip-tags`.

    Always run with `--check --diff` first and review the predicted changes
    (watching for unexpected `state: absent` teardowns) before repeating the
    same command without those flags to apply.

    Playbook runs and custom commands require a running SSH agent
    (`SSH_AUTH_SOCK`) holding the keys to connect to the nodes; the script
    forwards the agent socket into the Ansible container. The vault edit and
    view modes described below run `ansible-vault` only and do not need the
    agent. Shells that do not inherit the session environment (for example AI
    agent shells) must discover the socket and pass it explicitly: find it with
    `ls /tmp/ssh-*/agent.*`, verify the loaded keys with
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

    The script builds the Ansible container image on each run. To run an
    existing container image instead, set `ANSIBLE_CONTAINER_IMAGE_ID` to the
    container image to run, and `ANSIBLE_CONTAINER_IMAGE_SKIP_BUILD=true` to
    skip the build. The `Test Ansible collections, roles, playbooks` CI workflow
    uses these variables to build the container image once per job with the
    build cache that all the test jobs share. A Molecule run builds the
    `molecule` target under a tag with a `-molecule` suffix, so a test run and a
    playbook run never rebuild each other's image; before that suffix existed, a
    playbook run replaced the test image under a concurrent Molecule run
    (2026-10-22).

    To test a playbook with Molecule, set `ANSIBLE_TEST_DISTRO` to the container
    image of the test instance, `ANSIBLE_TEST_PLAYBOOK_NAME` to the name of the
    playbook to test, and pass the Molecule command to run:

    ```shell
    ANSIBLE_TEST_DISTRO="geerlingguy/docker-debian12-ansible:latest" \
      ANSIBLE_TEST_PLAYBOOK_NAME="bootstrap" \
      scripts/run-ansible.sh "molecule test"
    ```

    The test starts a privileged container for the test instance, and removes it
    when the test completes. Molecule skips the tasks that have the
    `molecule-notest` tag: tests don't pull container images, and don't start
    containerized services.

    A full `main` run converges every stack twice (converge and idempotence) and
    takes about eight minutes. While iterating on one stack, scope both passes
    with `ANSIBLE_TEST_TAGS`, which takes the same value as the `--tags` flag of
    a production run (the stack tag plus `untagged`, as the
    [Ansible development guide](./ansible.md) describes):

    ```shell
    ANSIBLE_TEST_DISTRO="geerlingguy/docker-debian12-ansible:latest" \
      ANSIBLE_TEST_PLAYBOOK_NAME="main" \
      ANSIBLE_TEST_TAGS="zigbee2mqtt,untagged" \
      scripts/run-ansible.sh "molecule test"
    ```

    A stack that starts a service also needs `install-debian-packages` in the
    scope: the package install task runs only when the run names that tag, and
    without it the service's dependencies (`python3-venv` for `monitoring-apt`)
    are missing when the unit starts.

    Unset, the variable selects every task, which is what CI runs. Run the full
    unscoped test once before pushing: a scoped run does not exercise the other
    stacks' tasks, nor the tasks that consume the registered results of tasks
    the scope skipped.

    Both variables are required: `ANSIBLE_TEST_DISTRO` also switches the
    container image build to the target that contains Molecule, so a bare
    `scripts/run-ansible.sh "molecule test"` fails with
    `exec: "molecule": executable file not found`. The SSH agent socket is
    required for Molecule runs too, because the script forwards it before
    checking the command: set `SSH_AUTH_SOCK` as described above.

- `scripts/run-terraform.sh`: iterates over the numbered Terraform service
  directories in `config/terraform` and runs `terraform init` and
  `terraform apply` for each one. Run
  `scripts/run-terraform.sh output <service> [<output-name>]` to print a
  service's outputs as JSON instead. The script needs `terraform` from the
  `operations` Nix shell. Reviewing and applying in two passes: with stdin
  closed (`</dev/null`) the stacks without changes complete and the first stack
  with changes prints its plan and aborts at the approval prompt; after
  reviewing that plan, a run with a single approval on stdin
  (`printf 'yes\n' | nix develop ./config/nix#operations --command scripts/run-terraform.sh`)
  applies that stack and still aborts at the next stack with changes, so nothing
  later is applied unreviewed. The approved run plans again, so compare its plan
  with the reviewed one before trusting the apply.

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
