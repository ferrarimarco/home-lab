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

## How to inspect the generated Nix test script

Because the Python test script is dynamically generated via Nix string
interpolation, you cannot read it directly in the host's `test.nix`.

To dry-run evaluate and inspect the exact compiled Python script that will be
executed for a given host, run:

```shell
nix eval --raw .#checks.x86_64-linux.<hostname>-test.testScript
```

This will print the complete generated Python source directly to your terminal.

## Nix commands

- `nix flake metadata <path>`: show flake metadata
- `nix flake show <path>`: show information about the flake
