locals {
  env = "prod"
}

provider "google" {
  region = var.google_default_region
  zone   = var.google_default_zone
}

data "google_organization" "ferrari_how" {
  domain = var.google_organization_domain
}

resource "google_project" "ferrarimarco_iac" {
  billing_account = var.google_billing_account_id
  name            = var.google_iac_project_id
  project_id      = var.google_iac_project_id
  org_id          = data.google_organization.ferrari_how.org_id

  auto_create_network = false
}

resource "google_storage_bucket" "terraform_state" {
  name                        = "${var.google_iac_project_id}-terraform-state"
  location                    = "US"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# To get environment-specific configuration
locals {
  terraform_environment_configuration_directory_path = "${var.configuration_directory_name}/${var.configuration_terraform_environments_directory_name}/${var.configuration_terraform_environment_name}"
}

# Main configuration values
locals {
  default_project_vpc_name   = "${var.google_default_project_id}-vpc"
  public_keys_directory_path = var.configuration_public_keys_directory_name

}

# IoT Core paths
locals {
  compute_engine_development_workstation_ssh_public_key_file_path = "${local.compute_engine_public_keys_directory_path}/${var.configuration_compute_engine_development_workstation_ssh_public_key_file_name}"
  compute_engine_public_keys_directory_path                       = "${local.public_keys_directory_path}/${var.configuration_compute_engine_keys_directory_name}"
}

# Compute Engine paths
locals {
  iot_core_public_keys_directory_path      = "${local.public_keys_directory_path}/${var.configuration_iot_core_keys_directory_name}"
  iot_core_smart_desk_public_key_file_path = "${local.iot_core_public_keys_directory_path}/${var.configuration_iot_core_smart_desk_public_key_file_name}"
}

resource "google_compute_network" "default-vpc" {
  name                    = local.default_project_vpc_name
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
  compute_engine_keys_directory_path                 = local.compute_engine_public_keys_directory_path
  iot_core_keys_directory_path                       = local.iot_core_public_keys_directory_path
  google_project_id                                  = var.google_iac_project_id
  google_project_number                              = google_project.ferrarimarco_iac.number
  google_organization_id                             = data.google_organization.ferrari_how.org_id
  terraform_environment_configuration_directory_path = local.terraform_environment_configuration_directory_path
}

module "iot" {
  source                                             = "../../modules/iot"
  configuration_bucket_name                          = module.iac-pipeline.configuration_bucket_name
  iot_core_smart_desk_public_key_file_path           = local.iot_core_smart_desk_public_key_file_path
  google_organization_id                             = data.google_organization.ferrari_how.org_id
  google_project_id                                  = var.google_iot_project_id
  terraform_environment_configuration_directory_path = local.terraform_environment_configuration_directory_path
}

module "development-workspace" {
  source                                                          = "../../modules/development-workspace"
  compute_engine_development_workstation_ssh_public_key_file_path = local.compute_engine_development_workstation_ssh_public_key_file_path
  configuration_bucket_name                                       = module.iac-pipeline.configuration_bucket_name
  development_workstation_google_compute_subnetwork_self_link     = google_compute_subnetwork.default-subnet.self_link
  development_workstation_machine_type                            = var.development_workstation_machine_type
  development_workstation_min_cpu_platform                        = var.development_workstation_min_cpu_platform
  development_workstation_name                                    = var.development_workstation_name
  development_workstation_ssh_user                                = var.development_workstation_ssh_user
  google_organization_id                                          = data.google_organization.ferrari_how.org_id
  google_project_id                                               = var.google_iot_project_id
  terraform_environment_configuration_directory_path              = local.terraform_environment_configuration_directory_path
}

module "configuration" {
  source                                         = "../../modules/configuration"
  configuration_gke_cluster_node_pool_size       = var.configuration_gke_cluster_node_pool_size
  configuration_gke_cluster_subnet_ip_cidr_range = var.configuration_gke_cluster_subnet_ip_cidr_range
  google_compute_network_vpc_name                = google_compute_network.default-vpc.name
  google_compute_subnetwork_vpc_name             = google_compute_subnetwork.default-subnet.name
  google_organization_id                         = data.google_organization.ferrari_how.org_id
  google_project_id                              = var.google_configuration_project_id
  google_region                                  = var.google_default_region
}
