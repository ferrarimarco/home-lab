variable "cloud_build_trigger_repository_name" {
  default     = "home-lab"
  description = "Name of the repository to set up Cloud Build triggers"
}

variable "cloud_build_trigger_repository_owner" {
  default     = "ferrarimarco"
  description = "Owner of the repository to set up Cloud Build triggers"
}

variable "configuration_compute_engine_development_workstation_ssh_public_key_file_name" {
  default     = "development-workstation-ssh-user.pub"
  description = "Name of the public key file to use for the development workstation"
}

variable "configuration_compute_engine_keys_directory_name" {
  default     = "compute-engine"
  description = "Name of the Compute Engine public keys directory"
}

variable "configuration_gke_cluster_node_pool_size" {
  default     = 1
  description = "Number of nodes of the node pool used in the configuration GKE cluster"
}

variable "configuration_gke_cluster_subnet_ip_cidr_range" {
  default     = "10.10.0.0/24"
  description = "IP CIDR for the Configuration GKE cluster"
}

variable "configuration_iot_core_keys_directory_name" {
  default     = "iot-core"
  description = "Name of the IoT Core public keys directory"
}

variable "configuration_iot_core_smart_desk_public_key_file_name" {
  default     = "smart_desk.pem"
  description = "Name of the public key file to use to register the Smart Desk to IoT Core"
}

variable "configuration_public_keys_directory_name" {
  default     = "public-keys"
  description = "Name of the public keys directory"
}

variable "configuration_directory_name" {
  default     = "terraform"
  description = "Name of the Terraform configuration directory"
}

variable "configuration_terraform_environments_directory_name" {
  default     = "environments"
  description = "Name of the Terraform configuration directory"
}

variable "configuration_terraform_environment_name" {
  description = "Name of the Terraform configuration directory"
}

variable "configuration_consul_datacenter_name" {
  default     = "configuration-datacenter"
  description = "Name of the configuration Consul datacenter"
}

variable "configuration_consul_chart_version" {
  default     = "0.24.1"
  description = "Version of the Consul Helm chart to install Consul in the configuration environment"
}

variable "configuration_gke_version_prefix" {
  default     = "1.17.9-gke.1504"
  description = "GKE version for the configuration environment."
}

variable "configuration_opentelemetry_collector_chart_version" {
  default     = "0.2.1"
  description = "Version of the opentelemetry-collector Helm chart to install in the configuration environment"
}

variable "default_container_registry_url" {
  default     = "gcr.io"
  description = "Default Container Registry URL"
}

variable "edge_prometheus_scrape_interval" {
  default     = "10s"
  description = "Default Prometheus scrape interval for edge devices"
}

variable "google_configuration_project_id" {
  description = "Google Cloud project ID for the configuration environment"
}

variable "google_default_region" {
  description = "The default Google Cloud region"
}

variable "google_default_zone" {
  description = "The default Google Cloud zone"
}

variable "google_default_project_id" {
  description = "Google Cloud default project ID"
}

variable "google_organization_domain" {
  description = "The default organization domain for Google Cloud projects"
}

variable "google_iot_project_id" {
  description = "Google Cloud project ID for the IoT environment"
}

variable "google_billing_account_id" {
  description = "The default billing account for Google Cloud projects"
}

variable "google_iac_project_id" {
  description = "Google Cloud project ID for the IaC pipeline"
}

variable "development_workstation_boot_disk_size" {
  default     = 200
  description = "Size of the development workstation boot disk, in GB"
}

variable "development_workstation_git_repositories_to_clone" {
  default = [
    "https://github.com/ferrarimarco/dotfiles.git",
    "https://github.com/ferrarimarco/home-lab.git"
  ]
  description = "Git repositories to clone in the development workstation"
}

variable "development_workstation_machine_type" {
  default     = "n2-standard-8"
  description = "Machine type for development workstations"
}

variable "development_workstation_min_cpu_platform" {
  default     = "Intel Cascade Lake"
  description = "Minimum CPU platform required for development workstations"
}

variable "development_workstation_name" {
  default     = "dev-linux-1"
  description = "Name of the development workstation"
}

variable "development_workstation_ssh_user" {
  description = "Username of the user to connect to the development workstation via SSH"
}

variable "development_workstation_update_git_remotes_to_ssh" {
  default     = true
  description = "When true, Git remotes of the repositories cloned in the development workstation will be updated to use SSH after being cloned via HTTP"
}

variable "edge_beaglebone_black_ethernet_ipv4_address" {
  default     = "10.0.0.2"
  description = "IPv4 static address of the BeagleBone Black ethernet interface."
}

variable "edge_default_gateway_ipv4_address" {
  default     = "10.0.0.1"
  description = "Default gateway IPv4 address in the edge environment."
}

variable "edge_dns_zone_prefix" {
  default     = "edge"
  description = "Prefix of the edge DNS zone. The main DNS zone is appended to this prefix."
}

variable "edge_external_dns_servers_primary" {
  default     = "8.8.8.8"
  description = "External DNS servers to forward queries to, outside the edge DNS domain."
}

variable "edge_external_dns_servers_secondary" {
  default     = "8.8.4.4"
  description = "External DNS servers to forward queries to, outside the edge DNS domain."
}

variable "edge_main_subnet_dhcp_lease_time" {
  default     = "2h"
  description = "Default DHCP lease time of the main subnet in the edge environment."
}

variable "edge_main_subnet_ipv4_address" {
  default     = "10.0.0.0/8"
  description = "Subnet address and suffix of the main IPv4 subnet address in the edge environment."
}

variable "edge_main_subnet_ipv4_address_range_end" {
  default     = "10.254.254.254"
  description = "Start (inclusive) of the IPv4 address range of the main subnet in the edge environment."
}

variable "edge_main_subnet_ipv4_address_range_start" {
  default     = "10.0.0.50"
  description = "End (inclusive) of the IPv4 address range of the main subnet in the edge environment."
}

variable "edge_mqtt_container_image_id" {
  default     = "eclipse-mosquitto:464870d"
  description = "Container image tag of the MQTT runtime."
}

variable "edge_iot_core_key_bits" {
  default     = 4096
  description = "Key length for IoT Core"
}

variable "edge_iot_core_credentials_validity" {
  default     = 86400
  description = "Default validity for the generated IoT Core credentials, in seconds"
}

variable "iot_core_initializer_container_image_id" {
  default     = "iot-core-initializer:3105e64"
  description = "Container image tag of the IoT Core initializer"
}

variable "main_dns_zone_prefix" {
  description = "Prefix of the main DNS zone to manage. The organization domain is appended to this prefix."
}

variable "pubsubtogcs_cloudfunction_archive_object_name" {
  default     = "pubsubtogcs-a242da3bb9dc31a78c2fef52ba5e3f2919558afc.zip"
  description = "Path to the Pub/Sub to Cloud Storage archive file inside the Cloud Functions bucket"
}
