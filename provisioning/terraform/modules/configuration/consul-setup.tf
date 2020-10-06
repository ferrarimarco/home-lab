data "kubernetes_secret" "consul-bootstrap-acl-token" {
  depends_on = [
    helm_release.configuration-consul
  ]

  metadata {
    name      = "${local.consul_release_name}-bootstrap-acl-token"
    namespace = local.consul_namespace_name
  }

  provider = kubernetes.configuration-gke-cluster
}

# There is no need to fetch the CA and server TLS certificates because the HTTP
# API prestents a valid TLS certificate.
provider "consul" {
  address    = local.consul_dns_name
  datacenter = var.consul_datacenter_name
  scheme     = "https"
  token      = data.kubernetes_secret.consul-bootstrap-acl-token.data["token"]
}

locals {
  connman_config_path_ethernet         = "var/lib/connman/ethernet.config"
  connman_config_path_ethernet_service = "${local.connman_config_path_ethernet}/service_ethernet"
  connman_config_path_main             = "etc/connman/main.cfg"
  connman_config_path_main_general     = "${local.connman_config_path_main}/General"

  dnsmasq_conf_path = "${local.etc_dnsmasq_path}/dnsmasq.conf"

  edge_key_prefix = "edge"

  etc_dnsmasq_path                 = "etc/dnsmasq"
  etc_network_interfaces_usb0_path = "etc/network/interfaces.d/usb0.conf"
}

resource "consul_key_prefix" "beaglebone-black-configuration" {
  path_prefix = "${local.edge_key_prefix}/beaglebone-black/config/"

  subkeys = {
    "${local.connman_config_path_ethernet_service}/DeviceName"            = "eth0"
    "${local.connman_config_path_ethernet_service}/Type"                  = "ethernet"
    "${local.connman_config_path_ethernet_service}/IPv4"                  = "${var.beaglebone_black_ethernet_ipv4_address}/${cidrnetmask(var.edge_main_subnet_ipv4_address)}/${var.edge_default_gateway_ipv4_address}"
    "${local.connman_config_path_ethernet_service}/IPv6"                  = "auto"
    "${local.connman_config_path_ethernet_service}/IPv6.Privacy"          = "false"
    "${local.connman_config_path_ethernet_service}/Nameservers"           = join(",", [var.edge_external_dns_servers_primary, var.edge_external_dns_servers_secondary])
    "${local.connman_config_path_ethernet_service}/SearchDomains"         = var.edge_dns_zone
    "${local.connman_config_path_ethernet_service}/Domain"                = var.edge_dns_zone
    "${local.connman_config_path_main_general}/PreferredTechnologies"     = "ethernet,wifi"
    "${local.connman_config_path_main_general}/SingleConnectedTechnology" = false
    "${local.connman_config_path_main_general}/AllowHostnameUpdates"      = false
    "${local.connman_config_path_main_general}/PersistentTetheringMode"   = true
    "${local.connman_config_path_main_general}/NetworkInterfaceBlacklist" = "SoftAp0,usb0,usb1"
    "${local.etc_network_interfaces_usb0_path}/address"                   = "192.168.7.2"
    "${local.etc_network_interfaces_usb0_path}/netmask"                   = "255.255.255.252"
    "${local.etc_network_interfaces_usb0_path}/network"                   = "192.168.7.0"
    "${local.etc_network_interfaces_usb0_path}/gateway"                   = "192.168.7.1"
  }
}

resource "consul_key_prefix" "edge-dns-dhcp-configuration" {
  path_prefix = "${local.edge_key_prefix}/dnsmasq/"

  subkeys = {
    "${local.dnsmasq_conf_path}/dhcp-option-router"    = "option:router,${var.edge_default_gateway_ipv4_address}"
    "${local.dnsmasq_conf_path}/dhcp-range"            = "${var.edge_main_subnet_ipv4_address_range_start},${var.edge_main_subnet_ipv4_address_range_end},${cidrnetmask(var.edge_main_subnet_ipv4_address)},${var.edge_main_subnet_dhcp_lease_time}"
    "${local.dnsmasq_conf_path}/domain"                = "${var.edge_dns_zone},${var.edge_main_subnet_ipv4_address},local"
    "${local.dnsmasq_conf_path}/dns-servers/primary"   = var.edge_external_dns_servers_primary
    "${local.dnsmasq_conf_path}/dns-servers/secondary" = var.edge_external_dns_servers_secondary
  }
}
