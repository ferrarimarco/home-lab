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
