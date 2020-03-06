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
  rotation_period = var.google_cloudbuild_key_rotation_period

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
  member        = "serviceAccount:${var.google_project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_kms_crypto_key.cloudbuild-crypto-key
  ]
}

resource "google_cloudbuild_trigger" "cloudbuild-trigger" {
  project  = var.google_project_id
  provider = google-beta

  github {
    owner = "ferrarimarco"
    name  = "home-lab"

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

resource "google_organization_iam_custom_role" "iac-admin-role" {
  role_id     = "iac.pipelineRunner"
  org_id      = var.google_organization_id
  title       = "IaC Pipeline Runner"
  description = "This role gives the necessary permissions to the user that runs the IaC pipeline"
  permissions = [
    "billing.resourceAssociations.create"
    , "iam.roles.get"
    , "iam.roles.list"
    , "resourcemanager.organizations.getIamPolicy"
    , "resourcemanager.organizations.get"
    , "resourcemanager.projects.create"
    , "resourcemanager.projects.createBillingAssignment"
  ]

  depends_on = [
    google_project_service.iam-apis
  ]
}

resource "google_organization_iam_member" "cloudbuild_iam_member_iac_admin" {
  org_id = var.google_organization_id
  role   = google_organization_iam_custom_role.iac-admin-role.id
  member = "serviceAccount:${var.google_project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_project_service.cloudbuild-apis,
    google_organization_iam_custom_role.iac-admin-role
  ]
}
