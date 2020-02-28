resource "google_project_service" "cloudbuild-apis" {
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}
