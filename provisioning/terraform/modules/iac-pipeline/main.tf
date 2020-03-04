resource "google_project_service" "cloudresourcemanager-apis" {
  project = var.google_project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_project_service" "cloudbuild-apis" {
  project = var.google_project_id
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
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

resource "google_organization_iam_member" "cloudbuild_iam_member_organization_viewer" {
  org_id = var.google_organization_id
  role   = "roles/resourcemanager.organizationViewer"
  member = "serviceAccount:${var.google_project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_project_service.cloudbuild-apis
  ]
}

resource "google_organization_iam_member" "cloudbuild_iam_member_organization_browser" {
  org_id = var.google_organization_id
  role   = "roles/browser"
  member = "serviceAccount:${var.google_project_number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_project_service.cloudbuild-apis
  ]
}
