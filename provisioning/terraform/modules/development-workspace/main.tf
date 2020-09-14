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
    "https://www.googleapis.com/compute/v1/projects/vm-options/global/licenses/enable-vmx",
  ]
}

resource "google_compute_instance" "development-workstation" {
  project          = var.google_project_id
  name             = var.development_workstation_name
  machine_type     = var.development_workstation_machine_type
  min_cpu_platform = var.development_workstation_min_cpu_platform

  can_ip_forward = false

  boot_disk {
    initialize_params {
      image = "${google_compute_image.dev-workstation-image-ubuntu-2004.family}/${google_compute_image.dev-workstation-image-ubuntu-2004.name}"
      type  = "pd-ssd"
    }
  }

  metadata_startup_script = file("${path.module}/development-workstation-startup-script.sh")

  network_interface {
    network = "default"

    access_config {
      // Ephemeral IP
    }
  }
}
