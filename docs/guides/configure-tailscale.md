# Tailscale configuration

In this section, you configure new hosts to join a Tailscale network.

## Tailscale authentication keys

- If you want to automate authentication, you can specify an authentication key
    for each host using the `tailscale_authkey` variable. For more information
    about Tailscale authentication keys, see
    [Authentication keys](https://tailscale.com/kb/1085/auth-keys/).
    The alternative is to manually run the `tailscale up` command on the host,
    and follow the instructions to authenticate the host.
- If you prefer that the key for a particular host doesn't expire, you can
    disable
    [Tailscale key expiration](https://tailscale.com/kb/1028/key-expiry/).

## Enable subnet routes or exit nodes in the Tailscale console

If a Tailscale host advertises routes or advertises itself as an exit node, you
need to enable these features in the Tailscale console or using the Tailscale
API. For more information, see:

- [Subnet routers and traffic relay nodes](https://tailscale.com/kb/1019/subnets)
- [Exit nodes](https://tailscale.com/kb/1103/exit-nodes/)
