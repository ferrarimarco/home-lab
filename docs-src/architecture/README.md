# Home lab architecture overview

This document describes the architecture of the lab.

The following diagram shows the architectural layers that compose the lab:

```text
+---------------------+
|      Workloads      |
|---------------------|
|       Platform      |
|---------------------|
|  System | External  |
|---------------------|
|      Bootstrap      |
|---------------------|
| Hardware management |
|---------------------|
|  Physical hardware  |
+---------------------+
```

The scope of each layer is as follows:

- `Workloads`: manage user-facing applications.
- `Platform`: manage essential components to run workloads.
- `External`: manage external services.
- `System`: manage critical system components, such as the hypervisor.
- `Bootstrap`: manage automated configuration and deployment processes.
- `Hardware management`: manage physical hardware. Example: IPMI, Redfish, KVM.
- `Physical hardware`: provide hardware resources.

## Support content

This repository includes the following content to support provisioning,
configuration, and deployment processes:

- Development environment container configuration in the `.devcontainer`
  directory.
- GitHub-specific configuration in the `.github` directory.
- Configuration for each architectural layer and support tooling in the `config`
  directory.
- Container image descriptors in the `docker` directory.
- Documentation site in the `docs` directory.
- Source of the documentation site in the `docs-src` directory.
- Operational scripts in the `scripts` directory.
- Tests in the `test` directory.
