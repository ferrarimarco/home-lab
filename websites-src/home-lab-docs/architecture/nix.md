# Nix and NixOS

## Declarative VM testing framework

Integration tests for NixOS configurations are managed by a centralized,
service-aware generator at `config/nix/tests/make-test.nix`.

Rather than writing manual test scripts for every host, a host's `test.nix`
simply imports this generator and passes it the logical configuration. The
generator automatically performs compile-time analysis on the evaluated
configuration:

1.  **Dynamic Hardware Provisioning:** If the host enables the QEMU Guest Agent
    (`services.qemuGuest.enable = true`), the generator automatically configures
    the required QEMU `virtio-serial` hardware inside the test sandbox.
2.  **Dynamic Assertion Appending:** If the host enables key services like SSH
    (`services.openssh.enable = true`) or the Guest Agent, the generator
    automatically appends the corresponding port availability and systemd
    service checks to the test script.

This ensures the test suite remains zero-maintenance as host services change
over time.
