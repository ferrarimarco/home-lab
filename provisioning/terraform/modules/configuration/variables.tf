variable "dns_record_sets_main_zone" {
  default     = {}
  description = "Key-value map of record sets for the main DNS zone. The key is the record label. The value is a map to configure: record type, record TTL, record value."
}

variable "google_project_id" {}

variable "main_dns_zone" {
  description = "Main DNS zone to manage."
}
