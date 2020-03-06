variable "google_cloudbuild_key_rotation_period" {
  description = "The rotation period for the Cloud Build encryption key"
}

variable "google_default_region" {
  description = "The default Google Cloud region"
}

variable "google_default_zone" {
  description = "The default Google Cloud zone"
}

variable "google_organization_domain" {
  description = "The default organization domain for Google Cloud projects"
}

variable "google_iac_project_id" {
  description = "Google Cloud project ID for the IaC pipeline"
}

variable "google_iot_project_id" {
  description = "Google Cloud project ID for the IoT environment"
}

variable "google_billing_account_id" {
  description = "The default billing account for Google Cloud projects"
}

variable "google_terraform_state_bucket_id" {
  description = "The Terraform state bucket it"
}
