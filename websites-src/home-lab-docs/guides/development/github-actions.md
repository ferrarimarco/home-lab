# GitHub Actions workflows

This guide describes the conventions that the workflows under
`.github/workflows` follow.

## Triggers

A workflow that builds or tests starts on pull requests and on pushes to the
default branch, with the same path filter on both:

```yaml
on:
    push:
        branches:
            - master
        paths:
            - "<paths>"
    pull_request:
        paths:
            - "<paths>"
```

A push to another branch starts nothing, so a branch gets its runs by opening a
pull request, a draft one included. The other triggers a workflow may have (a
schedule, a manual dispatch, a call from another workflow) are not affected.

Until 2026-11-19 the push trigger had no branch filter, and the pull request
branches paid for it twice. A push run repeated the pull request's run for the
same commit. A push run also started on dependency update branches whose pull
request changed none of the workflow's paths (seen after rebases onto a default
branch that had changed them; the cause was not investigated further): the
documentation workflow ran 122 times on such branches against 12 pull request
runs. No workflow did anything on a branch push that it does not do on a pull
request: the steps that commit lint fixes or a built site run on pull requests
only, and Renovate does a dry run outside the default branch in both cases. The
path filters are what a branch filter can break: the shell script tests filtered
fewer paths on pull requests than on pushes, so that their push runs were the
only test of most scripts on a branch, and both events got the same paths with
the branch filter.

The push runs on branches other than the default one, in each workflow's most
recent runs as of 2026-11-19 (200 at most, from
`gh run list --workflow <file> --limit 200 --json event,headBranch`):

| Workflow                   | Push runs on other branches | Runs counted | Since      |
| -------------------------- | --------------------------- | ------------ | ---------- |
| `nix`                      | 105                         | 200          | 2026-08-10 |
| `build-container-images`   | 97                          | 200          | 2026-10-09 |
| `build-firmware-images`    | 102                         | 200          | 2026-03-25 |
| `test-ansible`             | 99                          | 200          | 2026-10-10 |
| `lint`                     | 70                          | 200          | 2026-10-27 |
| `documentation`            | 122                         | 200          | 2026-10-06 |
| `test-shell-scripts`       | 112                         | 175          | 2025-12-08 |
| `test-prometheus-rules`    | 69                          | 118          | 2026-10-20 |
| `test-python-requirements` | 50                          | 97           | 2026-09-14 |
| `renovate`                 | 40                          | 200          | 2026-07-17 |
| `build-arduino-projects`   | 25                          | 42           | 2025-12-08 |
| The site workflow          | 17                          | 36           | 2026-03-28 |

The two longest are `nix` (a median of 19 minutes per run) and
`build-container-images` (11 minutes).
