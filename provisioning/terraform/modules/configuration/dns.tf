resource "google_project_service" "cloud-dns-apis" {
  project = var.google_project_id
  service = "dns.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

resource "google_dns_managed_zone" "main-dns-zone" {
  name        = "main-zone"
  dns_name    = "${var.main_dns_zone}."
  description = "Main DNS zone"

  depends_on = [
    google_project_service.cloud-dns-apis
  ]

  project = var.google_project_id
}
