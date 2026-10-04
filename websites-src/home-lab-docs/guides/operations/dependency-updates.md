# Dependency updates

This guide describes how automated dependency updates work in this repository,
and how to troubleshoot them.

Two tools manage dependency updates:

- Dependabot opens the dependency update pull requests. Its configuration is in
  `.github/dependabot.yaml`.
- Renovate runs from the `Renovate` CI workflow, and only opens pull requests
  after an approval in the Dependency Dashboard issue. Its configuration is in
  `.github/renovate.json`.

The [specifications index](../../specs/README.md) tracks the migration of all
dependency updates to Renovate.

## Dependabot configuration conventions

- Each entry in `updates` groups its updates with the `groups` option, so
  Dependabot opens one pull request for each group of each entry.
- Groups match all dependencies (`"*"`). A dependency that matches no group gets
  its own pull request, so a gap in the patterns never hides an update.
- A dependency joins the first group it matches: list specific groups before a
  group that matches all dependencies.
- Each entry needs a unique combination of ecosystem and directories. To assign
  the dependencies in the same directory to different groups, use one entry with
  several groups.
- An `ignore` rule that names a dependency without versions removes that
  dependency before Dependabot looks it up. The `terraform` entry uses this for
  the built-in Terraform provider, which no registry serves.
- Don't use `multi-ecosystem-groups`: their pull requests stopped updating after
  their creation, and accumulated notices about a rebase that never completed.
  See the Dependabot issues
  [12903](https://github.com/dependabot/dependabot-core/issues/12903) and
  [12957](https://github.com/dependabot/dependabot-core/issues/12957).

To validate the syntax of the configuration file, check it against its schema in
a container:

```shell
docker run --rm --volume "$(pwd)/.github:/work:ro" python:3-slim sh -c \
  'pip install --quiet check-jsonschema \
    && check-jsonschema \
      --schemafile https://json.schemastore.org/dependabot-2.0.json \
      /work/dependabot.yaml'
```

The schema check only validates the syntax. Dependabot reads the configuration
file when you push it to the default branch, and starts a job for each entry.

## How Dependabot runs

- Jobs run as the `Dependabot Updates` CI workflow, one run for each entry.
- The `daily` schedule runs on weekdays.
- Pushing a change to the configuration file starts a run for each entry.
  Merging a pull request doesn't.
- Dependabot waits a few days after the release of a version before proposing
  it, unless the registry doesn't report publication dates.
- A job first checks for updates, and then a separate job refreshes each
  existing pull request. The title of a refresh job names the dependencies of
  the pull request.

## Troubleshoot Dependabot

Use the GitHub CLI from the `operations` Nix shell, as described in the
[Nix development shells guide](../development/nix-dev-shells.md).

1. List the latest runs, and find the run for the ecosystem to investigate:

    ```shell
    nix develop ./config/nix#operations --command \
      gh run list --workflow "Dependabot Updates" --limit 30
    ```

1. Save the log of the run to a file:

    ```shell
    nix develop ./config/nix#operations --command \
      gh run view <run-id> --log > <log file> 2>&1
    ```

1. Inspect the log:
    - The `Job definition` line shows how Dependabot interpreted the
      configuration: `dependency-groups`, `ignore-conditions`,
      `existing-group-pull-requests`, and whether the job refreshes a pull
      request (`updating-a-pull-request`).
    - The `Checking if <dependency> <version> needs updating` lines list the
      dependencies that the job considered. A dependency that doesn't appear was
      filtered out.
    - The `Results` table at the end of the log lists the pull requests that the
      job created, updated, or closed, and the dependencies that failed to
      update.

1. Compare the results with the pull requests:

    ```shell
    nix develop ./config/nix#operations --command \
      gh pr list --author "app/dependabot" \
      --json number,title,updatedAt,commits \
      --jq '.[] | "\(.number) \(.title) \(.commits[-1].committedDate)"'
    ```

    A pull request that Dependabot keeps updating has recent commits. A pull
    request whose description changes while its commits don't is stuck.

A job can succeed and create a pull request, and still report a failure for a
dependency that it couldn't look up. Read the `Results` table before treating a
failed run as a missing update.

Duplicate pull requests that touch the same manifest files point at overlapping
`directories` entries in the configuration. The pull request branch names are
the decisive evidence: Dependabot names them
`dependabot/<ecosystem>/<directory>/...`, so a branch rooted at one directory
whose pull request also changes another entry's manifest proves that the first
directory's job already covers both — the second entry registers the manifest
twice, and the competing jobs supersede each other's pull requests into
duplicates. This happened for the `pip` entries `/docker/ansible` and
`/docker/ansible/molecule`, fixed on 2026-10-04 by removing the subdirectory
entry.
