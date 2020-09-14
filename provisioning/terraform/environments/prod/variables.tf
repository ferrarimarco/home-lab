variable "google_default_region" {
  description = "The default Google Cloud region"
}

variable "google_default_zone" {
  description = "The default Google Cloud zone"
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

variable "google_terraform_state_bucket_id" {
  description = "The Terraform state bucket it"
}

variable "development_workstation_machine_type" {
  description = "Machine type for development workstations"
}

variable "development_workstation_min_cpu_platform" {
  description = "Minimum CPU platform required for development workstations"
}

variable "development_workstation_name" {
  description = "Name of the development workstation"
}

variable "development_workstation_ssh_public_key_file_path" {
  description = "Path to the file that contains the public key to connect to the development workstation via SSH"
}

variable "development_workstation_ssh_user" {
  description = "Username of the user to connect to the development workstation via SSH"
}

variable "smart_desk_public_key_pem_file_path" {
  description = "Path to the public key to use to register the Smart Desk to IoT Core"
}
