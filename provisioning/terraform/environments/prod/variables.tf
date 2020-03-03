variable "google_organization_domain" {
  default     = "ferrari.how"
  description = "The default organization domain for Google Cloud projects"
}

variable "google_iac_project_id" {
  default     = "ferrarimarco-iac"
  description = "Google Cloud project ID for the IaC pipeline"
}

variable "google_billing_account_id" {
  description = "The default billing account for Google Cloud projects"
}
