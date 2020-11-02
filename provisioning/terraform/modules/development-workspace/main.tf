resource "google_project_service" "compute-apis" {
  project = var.google_project_id
  service = "compute.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

data "google_compute_image" "ubuntu-2004" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}

resource "google_compute_image" "dev-workstation-image-ubuntu-2004" {
  project      = var.google_project_id
  name         = "dev-workstation-ubuntu-2004"
  description  = "OS image for the development workstation. Base: Ubuntu 20.04"
  family       = "dev-workstation"
  source_image = data.google_compute_image.ubuntu-2004.self_link

  licenses = [
    "https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/licenses/ubuntu-2004-lts",
    "https://www.googleapis.com/compute/v1/projects/vm-options/global/licenses/enable-vmx",
  ]

  guest_os_features {
    type = "MULTI_IP_SUBNET"
  }

  guest_os_features {
    type = "SEV_CAPABLE"
  }

  guest_os_features {
    type = "UEFI_COMPATIBLE"
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }
}

locals {
  development_workstation_ssh_public_key_content = fileexists(var.compute_engine_development_workstation_ssh_public_key_file_path) ? file(var.compute_engine_development_workstation_ssh_public_key_file_path) : ""
}

resource "google_storage_bucket_object" "development-workstations-public-key-file" {
  # Only create this resource if the source file is available
  count = local.development_workstation_ssh_public_key_content != "" ? 1 : 0

  name    = "${var.terraform_environment_configuration_directory_path}/${var.compute_engine_development_workstation_ssh_public_key_file_path}"
  bucket  = var.configuration_bucket_name
  content = local.development_workstation_ssh_public_key_content
}

resource "google_compute_address" "development_workstation_ip_address" {
  address_type = "EXTERNAL"
  description  = "External IP address of the development workstation"
  name         = "development-workstation-ip-address"
  network_tier = "PREMIUM"
  project      = var.google_project_id
}

output "development_workstation_hostname" {
  value = google_compute_instance.development-workstation[0].name
}

output "development_workstation_ip_address" {
  value = google_compute_address.development_workstation_ip_address.address
}

resource "google_compute_firewall" "allow_ssh_dev_workstation" {
  name    = "allow-ssh-development-workstation"
  network = var.development_workstation_google_compute_network_self_link
  project = var.google_project_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["development-workstation"]
}

resource "google_compute_instance" "development-workstation" {
  # Only create this resource if a public key is available
  count = local.development_workstation_ssh_public_key_content != "" ? 1 : 0

  project          = var.google_project_id
  name             = var.development_workstation_name
  machine_type     = var.development_workstation_machine_type
  min_cpu_platform = var.development_workstation_min_cpu_platform
  tags             = google_compute_firewall.allow_ssh_dev_workstation.target_tags

  can_ip_forward = false

  boot_disk {
    initialize_params {
      image = google_compute_image.dev-workstation-image-ubuntu-2004.self_link
      type  = "pd-ssd"
    }
  }

  metadata = {
    ssh-keys = "${var.development_workstation_ssh_user}:${local.development_workstation_ssh_public_key_content}"
  }

  metadata_startup_script = templatefile("${path.module}/development-workstation-startup-script.sh",
    {
      development_workstation_username        = var.development_workstation_ssh_user,
      dotfiles_repository_url                 = var.development_workstation_dotfiles_repository_url
      iot_core_credentials_validity           = var.development_workstation_iot_core_credentials_validity
      iot_core_initializer_container_image_id = var.development_workstation_iot_core_initializer_container_image_id
      iot_core_mqtt_client_container_image_id = var.development_workstation_mqtt_client_container_image_id
      iot_core_project_id                     = var.development_workstation_iot_core_project_id
      iot_core_registry_id                    = var.development_workstation_iot_core_registry_id
    }
  )

  network_interface {
    subnetwork = var.development_workstation_google_compute_subnetwork_self_link

    access_config {
      nat_ip       = google_compute_address.development_workstation_ip_address.address
      network_tier = "PREMIUM"
    }
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }
}
