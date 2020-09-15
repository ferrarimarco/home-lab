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
    type = "UEFI_COMPATIBLE"
  }

  guest_os_features {
    type = "VIRTIO_SCSI_MULTIQUEUE"
  }
}

resource "google_compute_instance" "development-workstation" {
  project          = var.google_project_id
  name             = var.development_workstation_name
  machine_type     = var.development_workstation_machine_type
  min_cpu_platform = var.development_workstation_min_cpu_platform

  can_ip_forward = false

  boot_disk {
    initialize_params {
      image = google_compute_image.dev-workstation-image-ubuntu-2004.self_link
      type  = "pd-ssd"
    }
  }

  metadata = {
    ssh-keys = "${var.development_workstation_ssh_user}:${file(var.compute_engine_development_workstation_ssh_public_key_file_path)}"
  }

  metadata_startup_script = file("${path.module}/development-workstation-startup-script.sh")

  network_interface {
    network = "default"

    access_config {
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
