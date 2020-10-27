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

resource "google_dns_record_set" "main_zone_record_set" {
  name         = "${each.key}.${google_dns_managed_zone.main-dns-zone.dns_name}"
  managed_zone = google_dns_managed_zone.main-dns-zone.name
  type         = each.value["record_type"]
  ttl          = each.value["record_ttl"]
  rrdatas      = each.value["record_data"]

  for_each = var.dns_record_sets_main_zone

  project = var.google_project_id
}

output "main_zone_dns_names" {
  value = {
    for record_set in google_dns_record_set.main_zone_record_set :
    record_set.name => record_set.type
  }
}
