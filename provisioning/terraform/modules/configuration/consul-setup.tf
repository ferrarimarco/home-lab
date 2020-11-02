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
  beaglebone_black_device_name = "beaglebone-black"

  connman_config_path_ethernet         = "var/lib/connman/ethernet.config"
  connman_config_path_ethernet_service = "${local.connman_config_path_ethernet}/service_ethernet"
  connman_config_path_main             = "etc/connman/main.conf"
  connman_config_path_main_general     = "${local.connman_config_path_main}/General"

  dnsmasq_conf_path = "${local.etc_dnsmasq_path}/dnsmasq.conf"

  edge_key_prefix = "edge"

  etc_dnsmasq_path           = "etc/dnsmasq"
  etc_eclipse_mosquitto_path = "etc/eclipse-mosquitto"

  mosquitto_conf_path = "${local.etc_eclipse_mosquitto_path}/mosquitto.conf"

  systemd_iot_core_init_script_path     = "${local.usr_local_bin_path}/init-iot-core.sh"
  systemd_start_mqtt_client_script_path = "${local.usr_local_bin_path}/start-mqtt-client.sh"

  usr_local_bin_path = "usr/local/bin"
}

resource "consul_key_prefix" "beaglebone-black-configuration" {
  path_prefix = "${local.edge_key_prefix}/${local.beaglebone_black_device_name}/config/"

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
    "${local.connman_config_path_main_general}/AllowHostnameUpdates"      = true
    "${local.connman_config_path_main_general}/PersistentTetheringMode"   = true
    "${local.connman_config_path_main_general}/NetworkInterfaceBlacklist" = "SoftAp0,usb0,usb1"
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

locals {
  mosquitto_configuration_path = "mosquitto"
}

resource "consul_key_prefix" "edge_iot_core_configuration" {
  path_prefix = "${local.edge_key_prefix}/iot-core/"

  subkeys = {
    "client-username"                = "unused"
    "credentials-validity"           = var.iot_core_credentials_validity
    "initializer-container-image-id" = var.iot_core_initializer_container_image_id
    "mqtt-endpoint-fqdn"             = "mqtt.googleapis.com"
    "mqtt-subscribed-messages-qos"   = 1
    "project-id"                     = var.edge_iot_core_registry_project_id
    "rsa-key-length-bits"            = var.iot_core_key_bits
    "registry-id"                    = var.edge_iot_core_registry_id

    "${local.mosquitto_configuration_path}/container-image-id"    = var.mqtt_container_image_ic
    "${local.mosquitto_configuration_path}/mqtt-protocol-version" = "mqttv311"
    "${local.mosquitto_configuration_path}/tls-version"           = "tlsv1.3"
  }
}
