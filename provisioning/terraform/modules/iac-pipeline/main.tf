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

resource "google_project_service" "cloudbuild-apis" {
  project = var.google_project_id
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true

  depends_on = [
    google_project_service.cloudbilling-apis
  ]
}

resource "google_project_service" "cloudkms-apis" {
  project = var.google_project_id
  service = "cloudkms.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_kms_key_ring" "cloudbuild-keyring" {
  name     = "cloud-build-keyring"
  location = "global"
  project  = var.google_project_id

  depends_on = [
    google_project_service.cloudkms-apis
  ]
}

resource "google_kms_crypto_key" "cloudbuild-crypto-key" {
  name            = "cloudbuild-crypto-key"
  key_ring        = google_kms_key_ring.cloudbuild-keyring.self_link
  rotation_period = "864000s"

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    google_kms_key_ring.cloudbuild-keyring
  ]
}

resource "google_kms_crypto_key_iam_member" "cloudbuild-crypto-key-iam-member" {
  crypto_key_id = google_kms_crypto_key.cloudbuild-crypto-key.id
  role          = "roles/cloudkms.cryptoKeyDecrypter"
  member        = "serviceAccount:${local.cloud_build_service_account_email}"

  depends_on = [
    google_kms_crypto_key.cloudbuild-crypto-key
  ]
}

resource "google_cloudbuild_trigger" "cloudbuild-trigger" {
  project  = var.google_project_id
  provider = google-beta
  name     = "infrastructure-provisioning"

  github {
    owner = var.cloud_build_trigger_repository_owner
    name  = var.cloud_build_trigger_repository_name

    push {
      branch = ".*"
    }
  }

  filename = "cloudbuild.yaml"

  depends_on = [
    google_project_service.cloudbuild-apis,
    google_kms_crypto_key_iam_member.cloudbuild-crypto-key-iam-member
  ]
}

resource "google_project_service" "iam-apis" {
  project = var.google_project_id
  service = "iam.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

locals {
  cloud_build_service_account_email = "${google_project.iac_project.number}@cloudbuild.gserviceaccount.com"
  cloud_build_service_account_id    = "serviceAccount:${local.cloud_build_service_account_email}"
}

resource "google_organization_iam_member" "organization-admin-cloud-build-memeber" {
  org_id = var.google_organization_id
  role   = "roles/resourcemanager.organizationAdmin"
  member = local.cloud_build_service_account_id
}

resource "google_organization_iam_member" "organization-role-admin-cloud-build-memeber" {
  org_id = var.google_organization_id
  role   = "roles/iam.organizationRoleAdmin"
  member = local.cloud_build_service_account_id
}

resource "google_organization_iam_member" "billing-admin-cloud-build-memeber" {
  org_id = var.google_organization_id
  role   = "roles/billing.admin"
  member = local.cloud_build_service_account_id
}

resource "google_organization_iam_binding" "container-admin-cloud-build-binding" {
  org_id = var.google_organization_id
  role   = "roles/container.admin"

  members = [
    local.cloud_build_service_account_id
  ]
}

resource "google_organization_iam_binding" "container-cluster-admin-cloud-build-binding" {
  org_id = var.google_organization_id
  role   = "roles/container.clusterAdmin"

  members = [
    local.cloud_build_service_account_id
  ]
}

resource "google_organization_iam_binding" "project-creator-cloud-build-binding" {
  org_id = var.google_organization_id
  role   = "roles/resourcemanager.projectCreator"

  members = [
    local.cloud_build_service_account_id
  ]
}

resource "google_storage_bucket" "cloudbuild-source" {
  name                        = "${var.google_project_id}_cloudbuild"
  project                     = var.google_project_id
  location                    = "US"
  uniform_bucket_level_access = true
}

resource "google_storage_bucket" "os-images" {
  name                        = "${var.google_project_id}-os-images"
  project                     = var.google_project_id
  location                    = "US"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_storage_bucket" "configuration" {
  name                        = "${var.google_project_id}-configuration"
  project                     = var.google_project_id
  location                    = "US"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# Upload environment-specific configuration files

locals {
  terraform_backend_file_name   = "backend.tf"
  terraform_variables_file_name = "terraform.tfvars"
}

resource "google_storage_bucket_object" "terraform-environment-configuration-directory" {
  name    = "${var.terraform_environment_configuration_directory_path}/"
  content = "Terraform environment configuration directory"
  bucket  = google_storage_bucket.configuration.name
}

resource "google_storage_bucket_object" "terraform-environment-backend-configuration" {
  name   = "${var.terraform_environment_configuration_directory_path}/${local.terraform_backend_file_name}"
  bucket = google_storage_bucket.configuration.name
  source = local.terraform_backend_file_name
}

resource "google_storage_bucket_object" "terraform-environment-variables-file" {
  name   = "${var.terraform_environment_configuration_directory_path}/${local.terraform_variables_file_name}"
  bucket = google_storage_bucket.configuration.name
  source = local.terraform_variables_file_name
}

resource "google_storage_bucket_object" "terraform-configuration-compute-engine-public-keys-directory" {
  name    = "${var.terraform_environment_configuration_directory_path}/${var.compute_engine_keys_directory_path}/"
  content = "Terraform configuration Compute Engine public keys directory"
  bucket  = google_storage_bucket.configuration.name
}

resource "google_storage_bucket_object" "terraform-configuration-consul-template-directory" {
  name    = "${var.terraform_environment_configuration_directory_path}/${var.consul_template_directory_path}/"
  content = "Terraform configuration Consul Template directory"
  bucket  = google_storage_bucket.configuration.name
}

output "cloud_build_service_account_id" {
  value = local.cloud_build_service_account_email
}

output "configuration_bucket_name" {
  value = google_storage_bucket.configuration.name
}

output "configuration_bucket_self_link" {
  value = google_storage_bucket.configuration.self_link
}

output "terraform_configuration_consul_template_directory" {
  value = trimsuffix(google_storage_bucket_object.terraform-configuration-consul-template-directory.name, "/")
}
