# Network configuration

## Network subnets

Network subnet planning strategy: `10.SITE_ID.VLAN_ID.HOST/24`

- Main subnet: `10.0.0.0/8`

## DNS zones, DNS servers, DNS resolvers, and DHCP servers

In this section, we describe the configuration of DNS zones, DNS servers, and
DNS resolvers.

### DNS zones

- Root DNS zone: `ferrari.how`
- Home lab subdomain: `lab.ferrari.how`
- Edge home lab subdomain: `edge.lab.ferrari.how`

### DNS servers

This environment contains the following DNS servers:

- Cloudflare DNS servers that act as authoritative name servers for the root DNS
  zone.
- A [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) instance running on
  the default gateway. It responds to DNS queries for the `edge.lab.ferrari.how`
  zone, and returns authoritative answers from DHCP leases
  ([source](https://lists.thekelleys.org.uk/pipermail/dnsmasq-discuss/2008q4/002670.html)),
  even if it doesn't run as an authoritative name server for the
  `edge.lab.ferrari.how` zone.

### DNS resolvers

This environment contains the following DNS resolvers:

- A dnsmasq instance running on the default gateway acts as a private, non
  recursive, caching, DNS resolver that uses
  [Google Public DNS](https://developers.google.com/speed/public-dns), as a
  public, recursive, caching DNS resolver.
- An [unbound](https://nlnetlabs.nl/projects/unbound/about/) instance acts as a
  private, recursive, caching DNS resolver.

### DHCP servers

This environment contains the following DHCP servers:

- A dnsmasq instance running on the default gateway with the following
  configuration:
  - Subnet: `10.0.0.0/8`
  - Gateway: `10.0.0.1`
