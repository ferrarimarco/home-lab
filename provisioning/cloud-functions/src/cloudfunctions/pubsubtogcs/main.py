import base64
import os

from google.cloud import storage

iot_core_device_id_key = "deviceId"
iot_core_device_num_id_key = "deviceNumId"
iot_core_device_registry_id_key = "deviceRegistryId"
iot_core_device_registry_location_key = "deviceRegistryLocation"
iot_core_device_registry_project_id_key = "projectId"
iot_core_message_subfolder_key = "subFolder"

pubsub_message_attributes_key = "attributes"
pubsub_payload_key = "data"

cloud_storage_bucket_name_environment_variable_name = (
    "CLOUD_STORAGE_IOT_CORE_TELEMETRY_DESTINATION_BUCKET_NAME"
)


def pubsub_to_gcs(event, context):
    """Background Cloud Function to be triggered by Pub/Sub to upload a file
    in Cloud Storage.

    Args:
        event (dict):  The dictionary with data specific to this type of
        event. The `data` field contains the PubsubMessage message. The
        `attributes` field will contain custom attributes if there are any.
        context (google.cloud.functions.Context): The Cloud Functions event
        metadata. The `event_id` field contains the Pub/Sub message ID. The
        `timestamp` field contains the publish time.
    """
    print("Uploading Pub/Sub message to Cloud Storage...")

    if pubsub_payload_key in event:
        pubsub_message_payload = base64.b64decode(event[pubsub_payload_key]).decode(
            "utf-8"
        )
    else:
        raise ValueError("Error: The Pub/Sub message doesn't have a payload.")

    if cloud_storage_bucket_name_environment_variable_name in os.environ:
        cloud_storage_destination_bucket_name = os.environ.get(
            cloud_storage_bucket_name_environment_variable_name
        )
    else:
        raise ValueError(
            "Error: Cannot find the {} environment variable.".format(
                cloud_storage_bucket_name_environment_variable_name
            )
        )

    cloud_storage_destination_file_path = get_cloud_storage_destination_file_path(
        event, context
    )

    storage_client = storage.Client()
    print("Getting the {} bucket...".format(cloud_storage_destination_bucket_name))
    bucket = storage_client.get_bucket(cloud_storage_destination_bucket_name)
    blob = bucket.blob(cloud_storage_destination_file_path)

    blob.upload_from_string(pubsub_message_payload)

    print(
        "Object uploaded as {} in the {} bucket\n".format(
            cloud_storage_destination_file_path, cloud_storage_destination_bucket_name
        )
    )


def get_cloud_storage_destination_file_path(pubsub_event, pubsub_event_context):
    """Returns a Cloud Storage file path according to the PubsubMessage message.

    Args:
        pubsub_event (dict):  The PubsubMessage message. The
        `attributes` field contains custom attributes if there are any.
    """
    if pubsub_message_attributes_key in pubsub_event:
        pubsub_message_attributes = pubsub_event[pubsub_message_attributes_key]
    else:
        raise ValueError(
            "{} (event timestamp: {}) Pub/Sub event doesn't have attributes.".format(
                pubsub_event_context.event_id, pubsub_event_context.timestamp
            )
        )

    print("Computing Cloud Storage destination file path...")
    if (
        iot_core_device_id_key in pubsub_message_attributes
        and iot_core_device_num_id_key in pubsub_message_attributes
        and iot_core_device_registry_id_key in pubsub_message_attributes
        and iot_core_device_registry_location_key in pubsub_message_attributes
        and iot_core_device_registry_project_id_key in pubsub_message_attributes
    ):
        print(
            "Message attributes contain IoT Core metadata. Assuming that the message comes from IoT Core."
        )
        return "{}/iot-core/{}/{}/{}/telemetry/{}/metrics".format(
            pubsub_message_attributes[iot_core_device_registry_project_id_key],
            pubsub_message_attributes[iot_core_device_registry_location_key],
            pubsub_message_attributes[iot_core_device_registry_id_key],
            pubsub_message_attributes[iot_core_device_id_key],
            pubsub_message_attributes[iot_core_message_subfolder_key],
        )
    else:
        raise ValueError(
            "Couldn't find a suitable Cloud Storage path for the {} (event timestamp: {}) Pub/Sub event.".format(
                pubsub_event_context.event_id, pubsub_event_context.timestamp
            )
        )
