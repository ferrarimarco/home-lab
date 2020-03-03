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
    google_project_service.cloudbuild-apis
  ]
}

resource "google_project_iam_member" "cloudbuild_iam_memeber_project_editor" {
  project = var.google_project_id
  role    = "roles/editor"
  member  = "serviceAccount:${var.google_project_id}@cloudbuild.gserviceaccount.com"
}

resource "google_organization_iam_member" "cloudbuild_iam_member_organization_viewer" {
  org_id = var.google_organization_id
  role   = "roles/viewer"
  member = "serviceAccount:${var.google_project_id}@cloudbuild.gserviceaccount.com"
}

resource "google_organization_iam_member" "cloudbuild_iam_member_project_creator" {
  org_id = var.google_organization_id
  role   = "roles/resourcemanager.projectCreator"
  member = "serviceAccount:${var.google_project_id}@cloudbuild.gserviceaccount.com"
}
