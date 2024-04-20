# Capture network traffic of a Proxmox VM

In order to capture the network traffic that goes through a network interface of
a Proxmox VM, do the following:

1. Get the Proxmox VM ID.
1. Get the Proxmox VM interface name.
1. On the Proxmox node that hosts the VM, check that there's a `tap` network
    interface named `tap<VM_ID>i<NET_INTERFACE_ID>`.
1. On the Proxmox node that hosts the VM, run `tcpdump` in order to capture
    network traffic to a file:

    ```sh
    tcpdump -i tap<VM_ID>i<NET_INTERFACE_ID> -n -w <filename>.pcap
    ```

Source: <https://www.apalrd.net/posts/2023/tip_pcap/>
