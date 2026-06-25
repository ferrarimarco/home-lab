# Nix development

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
