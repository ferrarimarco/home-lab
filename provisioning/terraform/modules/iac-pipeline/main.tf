resource "google_project_service" "cloudresourcemanager-apis" {
  service = "cloudresourcemanager.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_project_service" "cloudbuild-apis" {
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_cloudbuild_trigger" "cloudbuild-trigger" {
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
    google_project_service.cloudbuild-apis
  ]
}

resource "google_organization_iam_member" "binding" {
  org_id = var.organization_id
  role   = "roles/viewer"
  member = "serviceAccount:${var.iac_project_id}@cloudbuild.gserviceaccount.com"
}

resource "google_organization_iam_member" "binding" {
  org_id = var.organization_id
  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${var.iac_project_id}@cloudbuild.gserviceaccount.com"
}
