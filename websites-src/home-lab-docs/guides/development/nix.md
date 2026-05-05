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
