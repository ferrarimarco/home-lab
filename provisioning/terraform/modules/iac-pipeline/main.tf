resource "google_project" "iac_project" {
  billing_account = var.google_billing_account_id
  name            = var.google_project_id
  project_id      = var.google_project_id
  org_id          = var.google_organization_id

  auto_create_network = false
}

resource "google_storage_bucket" "terraform_state" {
  name                        = "${var.google_project_id}-terraform-state"
  location                    = "US"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_project_service" "cloudresourcemanager-apis" {
  project = var.google_project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_project_service" "cloudbilling-apis" {
  project = var.google_project_id
  service = "cloudbilling.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_project_service" "iam-apis" {
  project = var.google_project_id
  service = "iam.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}
