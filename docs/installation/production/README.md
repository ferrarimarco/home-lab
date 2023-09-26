# Initialize the home lab

To initialize the home lab, you need a _controller_, a machine that runs the
initialization process.

On the controller, you need the following software tools:

- [Git](https://git-scm.com/). Tested with Git version >= `2.25.0`.
- An OCI container runtime, such as Docker. Tested with Docker version >= `20.10`.

The controller also needs a connection to an IP network that can route packets
to the internet.

To initialize the home lab, do the following:

1. Clone this repository.
1. Change the working directory to the root of the cloned repository.
1. [Provision new, physical hosts](./provision-new-hosts.md).
1. Run the `scripts/run-ansible.sh` script.
