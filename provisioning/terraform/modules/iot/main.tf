resource "google_project_service" "cloud-iot-apis" {
  project = var.google_project_id
  service = "cloudiot.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "pubsub-apis" {
  project = var.google_project_id
  service = "pubsub.googleapis.com"

  disable_dependent_services = true
}

resource "google_pubsub_topic" "default-devicestatus" {
  name    = "default-devicestatus"
  project = var.google_project_id

  depends_on = [
    google_project_service.pubsub-apis
  ]
}

resource "google_pubsub_topic" "default-telemetry" {
  name    = "default-telemetry"
  project = var.google_project_id

  depends_on = [
    google_project_service.pubsub-apis
  ]
}

resource "google_cloudiot_registry" "home-registry" {
  name    = "home-registry"
  project = var.google_project_id

  depends_on = [
    google_project_service.cloud-iot-apis,
    google_project_service.pubsub-apis
  ]

  event_notification_configs {
    pubsub_topic_name = google_pubsub_topic.default-telemetry.id
  }

  state_notification_config = {
    pubsub_topic_name = google_pubsub_topic.default-devicestatus.id
  }

  http_config = {
    http_enabled_state = "HTTP_ENABLED"
  }

  mqtt_config = {
    mqtt_enabled_state = "MQTT_ENABLED"
  }
}

resource "google_storage_bucket" "smart_desk" {
  name                        = "ferrarimarco-smart-desk"
  project                     = var.google_project_id
  location                    = "US"
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

locals {
  smart_desk_public_key_file_content = fileexists(var.iot_core_smart_desk_public_key_file_path) ? file(var.iot_core_smart_desk_public_key_file_path) : ""
}

resource "google_storage_bucket_object" "smart-desk-public-key-file" {
  # Only create this resource if the source file is available
  count = local.smart_desk_public_key_file_content != "" ? 1 : 0

  name    = "${var.terraform_environment_configuration_directory_path}/${var.iot_core_smart_desk_public_key_file_path}"
  bucket  = var.configuration_bucket_name
  content = local.smart_desk_public_key_file_content
}

resource "google_cloudiot_device" "smart-desk" {
  # Only create this resource if a public key is available
  count = local.smart_desk_public_key_file_content != "" ? 1 : 0

  name     = "smart-desk"
  registry = google_cloudiot_registry.home-registry.id

  log_level = "INFO"

  gateway_config {
    gateway_type = "NON_GATEWAY"
  }

  credentials {
    public_key {
      format = "RSA_PEM"
      key    = local.smart_desk_public_key_file_content
    }
  }
}
