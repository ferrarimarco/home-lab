resource "google_project_service" "cloudfunctions_apis" {
  project = var.google_project_id
  service = "cloudfunctions.googleapis.com"

  disable_dependent_services = true
}

resource "google_storage_bucket" "iot_core_telemetry_destination_bucket" {
  name                        = "${var.google_project_id}-iot-core-telemetry"
  location                    = "US"
  project                     = var.google_project_id
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

resource "google_cloudfunctions_function" "pubsubtogcs_cloudfunction_iot_core_telemetry" {
  name                  = "pubsub-to-gcs"
  description           = "Save Pub/Sub messages to Cloud Storage."
  entry_point           = "pubsub_to_gcs"
  project               = var.google_project_id
  runtime               = "python38"
  source_archive_bucket = var.cloudfunctions_source_bucket_name
  source_archive_object = var.pubsubtogcs_cloudfunction_archive_object_name

  environment_variables = {
    "CLOUD_STORAGE_IOT_CORE_TELEMETRY_DESTINATION_BUCKET_NAME" : google_storage_bucket.iot_core_telemetry_destination_bucket.name
  }

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = var.iot_core_telemetry_pubsub_topic
  }
}

output "pubsubtogcs_cloudfunction_iot_core_telemetry_destination_bucket_name" {
  value = google_storage_bucket.iot_core_telemetry_destination_bucket.name
}
