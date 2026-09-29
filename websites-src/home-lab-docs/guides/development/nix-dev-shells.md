# Nix development shells

Command-line tooling for this repository is not installed on the host. It comes
from the Nix development shells that the flake in `config/nix` defines, so every
contributor and automation runs the same pinned tool versions.

The flake defines two shells:

| Shell        | Definition                               | Purpose                                         |
| :----------- | :--------------------------------------- | :---------------------------------------------- |
| `default`    | `config/nix/shells/shell.nix`            | Develop, format, and lint the Nix code.         |
| `operations` | `config/nix/shells/shell-operations.nix` | Provision, deploy, and operate the environment. |

The flake also registers both shells as flake checks (`shell-devShell` and
`shell-opsShell`), so `nix flake check` fails when a shell no longer builds. The
CI workflow does not build these checks.

## Use a shell

Run the following commands from the repository root.

- To open an interactive shell:

    ```shell
    nix develop ./config/nix#operations
    ```

    Omit the `#operations` suffix to open the `default` shell.

- To run a single command without opening an interactive shell:

    ```shell
    nix develop ./config/nix#operations --command <command> [<argument> ...]
    ```

Keep these points in mind:

- The shells write their activation banner to the standard error stream, and so
  does Nix for its own warnings (for example, the warning about uncommitted
  changes in the Git tree). The standard output stream only carries the output
  of the command, so it is safe to parse or to redirect to a file.
- Nix flakes evaluate only Git-tracked files: `git add` a new shell definition
  before using it.
- The operational scripts do not open a shell on their own. Scripts that depend
  on tools from a shell must run inside that shell.

## Default shell tools

| Tool      | Purpose                                                   |
| :-------- | :-------------------------------------------------------- |
| `deadnix` | Find unused code in Nix files.                            |
| `nixd`    | Nix language server, for editor integration.              |
| `nixfmt`  | Format Nix files.                                         |
| `statix`  | Lint Nix files for antipatterns and suggest replacements. |

To format and lint the whole Nix codebase, prefer the flake's formatter and
check, which run `deadnix`, `nixfmt`, and `statix` with the repository
configuration (`config/nix/treefmt.nix`). See the
[Nix development guide](./nix.md#nix-commands).

## Operations shell tools

| Tool             | Purpose                                                     | How to invoke                                              |
| :--------------- | :---------------------------------------------------------- | :--------------------------------------------------------- |
| `gh`             | Interact with GitHub: CI workflow runs, pull requests.      | Directly. See [GitHub CLI](#github-cli).                   |
| `jq`             | Parse and filter JSON, such as Terraform outputs.           | Directly.                                                  |
| `nixos-anywhere` | Install NixOS on hosts that have a `disko.nix` disk layout. | Through `scripts/bootstrap-host.sh`, inside the shell.     |
| `nixos-rebuild`  | Push a NixOS configuration to a running host over SSH.      | Through `scripts/bootstrap-host.sh`, inside the shell.     |
| `terraform`      | Provision the infrastructure.                               | Only through `scripts/run-terraform.sh`, inside the shell. |

The [operational scripts guide](./operational-scripts.md) describes the scripts
that wrap these tools.

### GitHub CLI

The [GitHub CLI](https://cli.github.com/) (`gh`) authenticates with per-user
state that `gh auth login` stores outside the repository. Verify it with
`gh auth status`.

Use the GitHub CLI to:

- Inspect CI workflow runs after a push, which matters most for the workflows
  that have no convenient local equivalent. List the runs for the current
  commit, then capture the logs of the failed jobs in full to a log file:

    ```shell
    nix develop ./config/nix#operations --command \
      gh run list --commit "$(git rev-parse HEAD)"
    nix develop ./config/nix#operations --command \
      gh run view <run-id> --log-failed > <log file> 2>&1
    ```

    To tell a regression from a failure that predates the change, compare with
    the latest runs of the same workflow on the default branch
    (`gh run list --workflow <workflow file> --branch master`).

- Review pull requests, including the ones that Dependabot and Renovate open
  (`gh pr list`, `gh pr view`, `gh pr checks`).
- Read issues and releases (`gh issue list`, `gh issue view`,
  `gh release list`).

Read-only subcommands (`list`, `view`, `checks`, `status`, and `gh api` GET
requests) are safe for discovery. Subcommands that change state on GitHub are
outward-facing and need explicit approval first: for example `gh pr create`,
`gh pr merge`, `gh pr comment`, `gh issue create`, `gh workflow run`,
`gh run rerun`, `gh release create`, and `gh api` requests with a method other
than GET.

Filter JSON output with the built-in `--jq` flag:

```shell
nix develop ./config/nix#operations --command \
  gh pr list --json number,title --jq '.[] | "\(.number) \(.title)"'
```

## Tools outside the shells

Some tools run in containers instead, through the scripts that the
[operational scripts guide](./operational-scripts.md) describes. Neither the
host nor the shells provide them:

- Ansible, including `ansible-vault`: `scripts/run-ansible.sh`.
- Linters and formatters for the languages other than Nix: `scripts/lint.sh` and
  `scripts/format.sh`.
- Material for MkDocs: `scripts/run-mkdocs.sh`.

## Add a tool to a shell

1. Add the package to the `packages` list of the shell definition, keeping the
   list sorted alphabetically.
1. Add a row for the tool to the matching table in this document, in the same
   change. If the tool needs usage guidance, add a dedicated section like the
   one for the [GitHub CLI](#github-cli).
1. Verify that the shell builds and provides the tool:

    ```shell
    nix develop ./config/nix#<shell> --command <tool> --version
    ```
