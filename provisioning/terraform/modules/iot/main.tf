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

resource "google_storage_bucket_object" "terraform-configuration-iot-core-public-keys-directory" {
  name    = "${var.iot_core_public_keys_storage_prefix}/"
  content = "Terraform configuration IoT Core public keys directory"
  bucket  = var.configuration_bucket_name
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

resource "google_storage_bucket_object" "terraform-configuration-iot-core-home-registry-public-keys-directory" {
  name    = "${var.iot_core_public_keys_storage_prefix}/${google_cloudiot_registry.home-registry.id}/"
  content = "Terraform configuration IoT Core Home registry public keys directory"
  bucket  = var.configuration_bucket_name
}

locals {
  grouped_iot_core_public_keys = {
    for public_key in fileset(var.iot_core_public_keys_directory_path, "**/*.pem") :
    trimsuffix(public_key, basename(public_key)) => public_key...
  }
}

resource "google_cloudiot_device" "iot-core-device" {
  name = basename(each.key)

  # Get the dirname of the directory containing the public key files
  registry = dirname(dirname(each.key))

  log_level = "INFO"

  gateway_config {
    gateway_type = "NON_GATEWAY"
  }

  dynamic "credentials" {
    for_each = each.value
    content {
      public_key {
        format = "RSA_PEM"
        key    = file("${var.iot_core_public_keys_directory_path}/${credentials.value}")
      }
    }
  }

  for_each = local.grouped_iot_core_public_keys
}
