import base64

import pytest
from cloudfunctions.pubsubtogcs.main import (
    cloud_storage_bucket_name_environment_variable_name,
    get_cloud_storage_destination_file_path,
    iot_core_device_id_key,
    iot_core_device_num_id_key,
    iot_core_device_registry_id_key,
    iot_core_device_registry_location_key,
    iot_core_device_registry_project_id_key,
    iot_core_message_subfolder_key,
    pubsub_message_attributes_key,
    pubsub_payload_key,
    pubsub_to_gcs,
)
from google.cloud import storage
from mock import MagicMock

mock_context = MagicMock()
mock_context.event_id = "617187464135194"
mock_context.timestamp = "2019-07-15T22:09:03.761Z"

iot_core_event_attributes = {
    iot_core_device_id_key: "dev-linux-1",
    iot_core_device_num_id_key: "1234567890123456",
    iot_core_device_registry_id_key: "test-registry",
    iot_core_device_registry_location_key: "us-central1",
    iot_core_device_registry_project_id_key: "google-cloud-project",
    iot_core_message_subfolder_key: "node-exporter",
}

expected_cloud_storage_bucket_name = "cloud-storage-bucket-name"

expected_cloud_storage_iot_core_telemetry_node_exporter_destination_path = "{}-iot-core-{}-{}-{}-telemetry-{}-metrics".format(
    iot_core_event_attributes[iot_core_device_registry_project_id_key],
    iot_core_event_attributes[iot_core_device_registry_location_key],
    iot_core_event_attributes[iot_core_device_registry_id_key],
    iot_core_event_attributes[iot_core_device_id_key],
    iot_core_event_attributes[iot_core_message_subfolder_key],
)


class TestClass:
    @pytest.fixture(autouse=True)
    def no_requests(self, monkeypatch):
        """Remove requests.sessions.Session.request for all tests.

        Tests that try making one will fail. This is a way to ensure
        that mocks that involve the requests module are in place.
        """
        monkeypatch.delattr("requests.sessions.Session.request")

    def test_pubsub_to_gcs_iot_core_telemetry_node_exporter(self, capsys, monkeypatch):
        cloud_storage_blob_mock = MagicMock()

        get_bucket_mock = MagicMock()
        monkeypatch.setattr(storage.Client, "get_bucket", get_bucket_mock)

        expected_blob_contents = "test"
        data = {
            pubsub_payload_key: base64.b64encode(expected_blob_contents.encode()),
            pubsub_message_attributes_key: iot_core_event_attributes,
        }

        # Set the expected environment variables
        monkeypatch.setenv(
            cloud_storage_bucket_name_environment_variable_name,
            expected_cloud_storage_bucket_name,
        )

        pubsub_to_gcs(data, mock_context)
        out, err = capsys.readouterr()
        assert "Uploading Pub/Sub message to Cloud Storage...\n" in out
        assert "Getting the {} bucket...\n".format(expected_cloud_storage_bucket_name)
        assert (
            "Object uploaded as {} in the {} bucket\n".format(
                expected_cloud_storage_iot_core_telemetry_node_exporter_destination_path,
                expected_cloud_storage_bucket_name,
            )
            in out
        )

        get_bucket_mock.assert_called_once_with(expected_cloud_storage_bucket_name)

        cloud_storage_bucket_mock = get_bucket_mock.return_value
        cloud_storage_bucket_mock.blob.assert_called_once_with(
            expected_cloud_storage_iot_core_telemetry_node_exporter_destination_path
        )

        cloud_storage_blob_mock = cloud_storage_bucket_mock.blob.return_value
        cloud_storage_blob_mock.upload_from_string.assert_called_once_with(
            expected_blob_contents
        )

    def test_get_cloud_storage_destination_file_path_iot_core(self, capsys):
        data = {
            pubsub_message_attributes_key: iot_core_event_attributes,
        }

        cloud_storage_destination_path = get_cloud_storage_destination_file_path(
            data, mock_context
        )

        out, err = capsys.readouterr()
        assert "Computing Cloud Storage destination file path...\n" in out
        assert (
            "Message attributes contain IoT Core metadata. Assuming that the message comes from IoT Core.\n"
            in out
        )

        assert (
            cloud_storage_destination_path
            == expected_cloud_storage_iot_core_telemetry_node_exporter_destination_path
        )
