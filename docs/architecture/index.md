# Architecture

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
- `System`: manage critical system components.
- `Bootstrap`: manage automated configuration and deployment processes.
- `Hardware management`: manage physical hardware.
- `Physical hardware`: provide hardware resources.

## Support contents

- GitHub-specific configuration in the `.github` directory.
- Configuration for each architectural layer and support tooling in the `config` directory.
- Container image descriptors in the `docker` directory.
- Documentation in the `docs` directory and in the [main README](../../README.md).
- Operational scripts in the `scripts` directory.

## Further reading

- [DNS zones, servers, and resolvers](./dns-zones-servers-resolvers.md)
- [References](./references.md)
