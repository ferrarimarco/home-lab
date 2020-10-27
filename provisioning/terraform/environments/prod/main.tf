provider "google" {
  region = var.google_default_region
  zone   = var.google_default_zone
}

data "google_organization" "main_organization" {
  domain = var.google_organization_domain
}

# Main configuration values
locals {
  edge_dns_zone              = "${var.edge_dns_zone_prefix}.${local.main_dns_zone}"
  main_dns_zone              = "${var.main_dns_zone_prefix}.${data.google_organization.main_organization.domain}"
  public_keys_directory_path = var.configuration_public_keys_directory_name

  # To get environment-specific configuration
  terraform_environment_configuration_directory_path = "${var.configuration_directory_name}/${var.configuration_terraform_environments_directory_name}/${var.configuration_terraform_environment_name}"
}

locals {
  compute_engine_public_keys_directory_path = "${local.public_keys_directory_path}/${var.configuration_compute_engine_keys_directory_name}"
  iot_core_public_keys_directory_path       = "${local.public_keys_directory_path}/${var.configuration_iot_core_keys_directory_name}"

  consul_template_directory_path = "consul-template"
}

resource "google_compute_network" "default-vpc" {
  name                    = "${var.google_default_project_id}-vpc"
  auto_create_subnetworks = "false"
  project                 = var.google_default_project_id
}

resource "google_compute_subnetwork" "default-subnet" {
  name          = "${var.google_default_project_id}-subnet"
  region        = var.google_default_region
  network       = google_compute_network.default-vpc.name
  ip_cidr_range = var.configuration_gke_cluster_subnet_ip_cidr_range
  project       = var.google_default_project_id
}

module "iac-pipeline" {
  source                                             = "../../modules/iac-pipeline"
  cloud_build_trigger_repository_name                = var.cloud_build_trigger_repository_name
  cloud_build_trigger_repository_owner               = var.cloud_build_trigger_repository_owner
  consul_template_directory_path                     = local.consul_template_directory_path
  compute_engine_keys_directory_path                 = local.compute_engine_public_keys_directory_path
  google_billing_account_id                          = var.google_billing_account_id
  google_project_id                                  = var.google_iac_project_id
  google_organization_id                             = data.google_organization.main_organization.org_id
  terraform_environment_configuration_directory_path = local.terraform_environment_configuration_directory_path
}

module "iot" {
  source                              = "../../modules/iot"
  configuration_bucket_name           = module.iac-pipeline.configuration_bucket_name
  configuration_bucket_self_link      = module.iac-pipeline.configuration_bucket_self_link
  google_organization_id              = data.google_organization.main_organization.org_id
  google_project_id                   = var.google_iot_project_id
  iot_core_public_keys_directory_path = local.iot_core_public_keys_directory_path
  iot_core_public_keys_storage_prefix = "${local.terraform_environment_configuration_directory_path}/${local.iot_core_public_keys_directory_path}"
}

module "development-workspace" {
  source                                                          = "../../modules/development-workspace"
  compute_engine_development_workstation_ssh_public_key_file_path = "${local.compute_engine_public_keys_directory_path}/${var.configuration_compute_engine_development_workstation_ssh_public_key_file_name}"
  configuration_bucket_name                                       = module.iac-pipeline.configuration_bucket_name
  development_workstation_google_compute_subnetwork_self_link     = google_compute_subnetwork.default-subnet.self_link
  development_workstation_machine_type                            = var.development_workstation_machine_type
  development_workstation_min_cpu_platform                        = var.development_workstation_min_cpu_platform
  development_workstation_name                                    = var.development_workstation_name
  development_workstation_ssh_user                                = var.development_workstation_ssh_user
  google_organization_id                                          = data.google_organization.main_organization.org_id
  google_project_id                                               = var.google_iot_project_id
  terraform_environment_configuration_directory_path              = local.terraform_environment_configuration_directory_path
}

module "configuration" {
  source                                         = "../../modules/configuration"
  beaglebone_black_ethernet_ipv4_address         = var.edge_beaglebone_black_ethernet_ipv4_address
  cloud_build_service_account_id                 = module.iac-pipeline.cloud_build_service_account_id
  configuration_bucket_name                      = module.iac-pipeline.configuration_bucket_name
  configuration_gke_cluster_node_pool_size       = var.configuration_gke_cluster_node_pool_size
  configuration_gke_cluster_subnet_ip_cidr_range = var.configuration_gke_cluster_subnet_ip_cidr_range
  consul_chart_version                           = var.configuration_consul_chart_version
  consul_datacenter_name                         = var.configuration_consul_datacenter_name
  consul_template_directory_path                 = module.iac-pipeline.terraform_configuration_consul_template_directory
  edge_default_gateway_ipv4_address              = var.edge_default_gateway_ipv4_address
  edge_dns_zone                                  = local.edge_dns_zone
  edge_external_dns_servers_primary              = var.edge_external_dns_servers_primary
  edge_external_dns_servers_secondary            = var.edge_external_dns_servers_secondary
  edge_main_subnet_dhcp_lease_time               = var.edge_main_subnet_dhcp_lease_time
  edge_main_subnet_ipv4_address                  = var.edge_main_subnet_ipv4_address
  edge_main_subnet_ipv4_address_range_end        = var.edge_main_subnet_ipv4_address_range_end
  edge_main_subnet_ipv4_address_range_start      = var.edge_main_subnet_ipv4_address_range_start
  gke_version_prefix                             = var.configuration_gke_version_prefix
  google_compute_network_vpc_name                = google_compute_network.default-vpc.name
  google_compute_subnetwork_vpc_name             = google_compute_subnetwork.default-subnet.name
  google_organization_id                         = data.google_organization.main_organization.org_id
  google_project_id                              = var.google_configuration_project_id
  google_region                                  = var.google_default_region
  main_dns_zone                                  = local.main_dns_zone

  dns_record_sets_main_zone = {
    (module.development-workspace.development_workstation_hostname) = {
      "record_ttl"  = 300
      "record_type" = "A"
      "record_data" = [module.development-workspace.development_workstation_ip_address]
    }
  }
}

output "main_zone_dns_names" {
  description = "DNS names defined in the main DNS zone"
  value       = module.configuration.main_zone_dns_names
}
