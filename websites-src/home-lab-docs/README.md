# Home lab

All the necessary to provision, configure and manage my home lab.

Before using the home lab, you initialization the environments by executing a
manual process. After the initialization process completes, automated processes
take care of applying provisioning and configuration changes to the
environments.

## Get started

For more information about how to set up the lab, see:

- [Initialize the home lab on physical hardware](./installation/production/README.md).

## Architecture

For the architecture of the lab, its design specifications, and the todo list,
see [Architecture](./architecture/README.md).

## Repository layout

The repository includes the following content to support provisioning,
configuration, and deployment processes:

- Development environment container configuration in the `.devcontainer`
  directory.
- GitHub-specific configuration in the `.github` directory.
- Configuration and support tooling in the `config` directory, split by tool.
- Container image descriptors in the `docker` directory.
- Documentation site in the `docs` directory.
- Source of the documentation site in the `websites-src` directory.
- Operational scripts in the `scripts` directory. The
  [operational scripts guide](./guides/development/operational-scripts.md)
  describes them.
- Tests in the `test` directory.
