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
