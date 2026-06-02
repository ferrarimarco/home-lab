# Configure Proxmox hosts, virtual machines, and containers

After provisioning a Proxmox host, you initialize it with Terraform. The
initialization process creates users, roles, and API tokens for the following
stages, and persists API tokens in Terraform variables files.

Terraform handles:

- The configuration of Proxmox hosts.
- The provisioning of Proxmox virtual machines (VMs) and LXC containers.

From your Linux shell, after setting the working directory to the root of this
repository:

1. Open the `operations` Nix shell, if needed:

    ```bash
    nix develop ./config/nix#operations
    ```

1. Apply changes with Terraform:

    ```bash
    scripts/run-terraform.sh
    ```

    To enable the configuration of the Proxmox IAM, create the following files:
    - `config/terraform/environments/proxmox-pve1-root-secrets.tfvars` to store
      the root credentials (password or API token) of the `pve1` host root
      password.
