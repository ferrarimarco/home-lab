# Nix development

## Run host integration tests

Every host directory under `config/nix/hosts/` with a `default.nix` is
automatically registered as a flake check named `host-<host>-test` (see the
[Declarative Integration Testing specification](../../specs/declarative-integration-testing.md)).
Run one host's test locally from the repository root with:

```shell
nix build ./config/nix#checks.x86_64-linux.host-<host>-test --no-link -L
```

Keep these points in mind:

- Nix flakes evaluate only Git-tracked files: `git add` newly created files (for
  example a new role directory) before building, or evaluation fails with a "not
  tracked by Git" error.
- Pass `--no-link` so the build does not clobber the repository's single
  `result` symlink, which the `220-proxmox-workloads` Terraform stack reads for
  staged image artifacts.
- When writing test script assertions, remember that `machine.succeed` runs
  commands under `pipefail`: an early-exiting pipe consumer such as `grep -q`
  closes the pipe while the producer is still writing large output, failing the
  pipeline with the producer's write error. Use a consumer that reads the full
  stream (for example `grep <pattern> > /dev/null`).

## Open a Python shell in a test virtual machine

1. Start the interactive test driver:

    ```shell
    nix run .#checks.x86_64-linux.<machine-name>-test.driverInteractive
    ```

    To exit the test driver, use the `CTRL-d` key combination.

1. Start all machines:

    ```python
    start_all()
    ```

1. Open a Linux shell:

    ```python
    machine.shell_interact()
    ```

## Nix GitOps

Nix machines run [comin](https://github.com/nlewo/comin) to implement GitOps.

Pushing commits to branches named `testing-<host-name>` makes comin pull
changes, apply them, but not update the bootloader to boot from the newly
generated configuration. Comin updates the bootloader when commits are pushed to
the default branch. For more info, see
[Comin how-tos](https://github.com/nlewo/comin/blob/main/docs/howtos.md).

If the default branch changes, update `config/nix/roles/comin/default.nix`
accordingly.

## Nix commands

- `nix flake metadata <path>`: show flake metadata
- `nix flake show <path>`: show information about the flake
- `nix fmt . -- --clear-cache`: format the Nix codebase
- `nix build .#checks.x86_64-linux.lint-treefmt-nix --verbose`: run linting and
  formatting checks
- `nixos-rebuild switch --flake ".#<host>" --target-host "<ssh-user>@<host>" --sudo`:
  apply changes to host when it's not running comin.
- `nix flake check <path>`: run all flake checks
- `nix build <path>#checks.<check-name>`: run a specific check
- `nix build <path>#<package-name>`: build specific package
    - `nix build --rebuild <path>#<package-name>`: rebuild a package
    - `nix build --print-build-logs <path>#<package-name>`: print build log
- `nix-store --gc`: clean the Nix store
