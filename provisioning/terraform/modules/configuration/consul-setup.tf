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
  beaglebone_black_configuration_prefix = "beaglebone-black/config/"
  connman_config_path_ethernet          = "var/lib/connman/ethernet.config"
  connman_config_path_ethernet_service  = "${local.connman_config_path_ethernet}/service_ethernet"
  connman_config_path_main              = "etc/connman/main.cfg"
  connman_config_path_main_general      = "${local.connman_config_path_main}/General"
  consul_configuration_path             = "${path.module}/consul"
  etc_network_interfaces_usb0_path      = "etc/network/interfaces.d/usb0.conf"
}

resource "consul_key_prefix" "beaglebone-black-configuration" {
  path_prefix = local.beaglebone_black_configuration_prefix

  subkeys = {
    "${local.connman_config_path_ethernet_service}/DeviceName"            = "eth0"
    "${local.connman_config_path_ethernet_service}/Type"                  = "ethernet"
    "${local.connman_config_path_ethernet_service}/IPv4"                  = "192.168.0.5/255.255.0.0/192.168.0.1"
    "${local.connman_config_path_ethernet_service}/IPv6"                  = "auto"
    "${local.connman_config_path_ethernet_service}/IPv6.Privacy"          = "false"
    "${local.connman_config_path_ethernet_service}/Nameservers"           = "8.8.8.8,8.8.4.4"
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
