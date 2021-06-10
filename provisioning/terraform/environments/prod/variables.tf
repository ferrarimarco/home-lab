variable "cloud_build_trigger_repository_name" {
  default     = "home-lab"
  description = "Name of the repository to set up Cloud Build triggers"
}

variable "cloud_build_trigger_repository_owner" {
  default     = "ferrarimarco"
  description = "Owner of the repository to set up Cloud Build triggers"
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

variable "default_container_registry_url" {
  default     = "gcr.io"
  description = "Default Container Registry URL"
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

variable "google_billing_account_id" {
  description = "The default billing account for Google Cloud projects"
}

variable "google_iac_project_id" {
  description = "Google Cloud project ID for the IaC pipeline"
}

variable "main_dns_zone_prefix" {
  description = "Prefix of the main DNS zone to manage. The organization domain is appended to this prefix."
}
