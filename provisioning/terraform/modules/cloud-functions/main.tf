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

resource "google_service_account" "iot_core_telemetry_read_only" {
  account_id   = "iot-core-telemetry-bucket-ro"
  description  = "Service Account with read-only access to the ${google_storage_bucket.iot_core_telemetry_destination_bucket.name} bucket"
  display_name = "${google_storage_bucket.iot_core_telemetry_destination_bucket.name} read-only Service Account"
  project      = var.google_project_id
}

data "google_iam_policy" "iot_core_telemetry_bucket_read_only_policy" {
  binding {
    members = [
      "serviceAccount:${google_service_account.iot_core_telemetry_read_only.email}"
    ]
    role = "roles/storage.objectViewer"
  }

  binding {
    members = [
      "serviceAccount:${var.cloud_build_service_account_email}"
    ]
    role = "roles/storage.admin"
  }

  binding {
    members = [
      "serviceAccount:${var.google_project_id}@appspot.gserviceaccount.com"
    ]
    role = "roles/storage.legacyBucketWriter"
  }

  depends_on = [
    google_project_service.cloudfunctions_apis
  ]
}

resource "google_storage_bucket_iam_policy" "iot_core_telemetry_bucket_read_only_storage_iam_policy" {
  bucket      = google_storage_bucket.iot_core_telemetry_destination_bucket.name
  policy_data = data.google_iam_policy.iot_core_telemetry_bucket_read_only_policy.policy_data
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

output "pubsubtogcs_cloudfunction_iot_core_telemetry_destination_bucket_read_only_service_account" {
  value = google_service_account.iot_core_telemetry_read_only
}
