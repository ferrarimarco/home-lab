# References

## Home Assistant

- How to change the
  [NUT integration configuration](https://community.home-assistant.io/t/how-do-i-change-nut-ip-address/597162/5).
- [Awesome Home Assistant](https://www.awesome-ha.com/): a curated list of Home
  Assistant integrations, add-ons, and resources.

## Home lab examples

- [khuedoan/homelab](https://github.com/khuedoan/homelab)
- [niki-on-github/nixos-k3s](https://github.com/niki-on-github/nixos-k3s/):
  single-node k3s on NixOS, installed with nixos-anywhere and disko, Flux for
  GitOps, and a fallback Git server on the host for recovery.
- [clearlybaffled/homelab](https://github.com/clearlybaffled/homelab): kubeadm
  on Debian provisioned by Ansible, Argo CD, and a scripted offline root CA.

## Software directories

- [awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted):
  a curated list of self-hosted software.
- [awesome-sysadmin](https://github.com/awesome-foss/awesome-sysadmin): a
  curated list of system administration software.
- [awesome-arr](https://github.com/Ravencentric/awesome-arr): the arr media
  automation ecosystem.
- [Open Source Security Index](https://opensourcesecurityindex.io/): a ranking
  of open source security projects by activity.
- [Privacy Guides](https://www.privacyguides.org/): recommendations for privacy
  tools and services, including DNS resolvers and VPN providers.

## Nix and NixOS

- [NixOS flakes tutorial](https://www.tweag.io/blog/2020-07-31-nixos-flakes/)
- [Integration testing with NixOS in GitHub Actions](https://jnsgr.uk/2024/02/nixos-vms-in-github-actions/)
- [Building a NixOS-Based NAS](https://danielunderwood.dev/post/nixos-nas/):
  LUKS under ZFS, with the root volume unlocked over SSH from the initrd.
- [Paranoid NixOS Setup](https://xeiaso.net/blog/paranoid-nixos-2021-07-18/):
  defence in depth with the firewall, systemd sandboxing, a restricted Nix
  daemon, a tmpfs root, audit rules, and noexec mounts.

### Nix commands

- [`nix develop`](https://nix.dev/manual/nix/2.18/command-ref/new-cli/nix3-develop):
  useful to recreate build environments for a package.
- [`nix shell`](https://nix.dev/manual/nix/2.18/command-ref/new-cli/nix3-shell):
  run a shell in which the specified packages are available.
- [`nix run`](https://nix.dev/manual/nix/2.18/command-ref/new-cli/nix3-run): run
  a command in a shell in which the specified packages are available.

#### Nix shells

- [Nix shells](https://blog.ysndr.de/posts/guides/2021-12-01-nix-shells)

## ZFS

- [ZFS: You should use mirror vdevs, not RAIDZ](https://jrs-s.net/2015/02/06/zfs-you-should-use-mirror-vdevs-not-raidz/)
- [Choosing the right ZFS pool layout](https://klarasystems.com/articles/choosing-the-right-zfs-pool-layout/),
  by Klara Systems

## Out-of-band management

- [DIY out-of-band management: remote console server](https://michael.stapelberg.ch/posts/2022-08-27-out-of-band-remote-console/),
  by Michael Stapelberg: a gokrazy Raspberry Pi serial console reached over
  Tailscale, plus a Tasmota smart plug for power cycling.

## Immutable infrastructure

- [Erase your darlings](https://grahamc.com/blog/erase-your-darlings/), by
  Graham Christensen
- [Encrypted Btrfs Root with Opt-in State on NixOS](https://mt-caret.github.io/blog/posts/2020-06-29-optin-state.html),
  by mt_caret: the Btrfs variant, with a script to discover accumulated state.
