data "google_client_config" "google-provider-configuration" {
}

resource "google_project_service" "kubernetes-engine-apis" {
  project = var.google_project_id
  service = "container.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = true
}

data "google_container_engine_versions" "gke-version" {
  project        = var.google_project_id
  location       = var.google_region
  version_prefix = var.gke_version_prefix
}

resource "google_container_cluster" "configuration-gke-cluster" {
  min_master_version = data.google_container_engine_versions.gke-version.latest_node_version
  name               = "${var.google_project_id}-configuration"
  project            = var.google_project_id
  provider           = google-beta
  location           = var.google_region

  # Create the smallest possible default node pool and then remove it
  # because we want to use a managed node pool
  remove_default_node_pool = true
  initial_node_count       = 1

  enable_intranode_visibility = true
  network                     = var.google_compute_network_vpc_name
  subnetwork                  = var.google_compute_subnetwork_vpc_name

  ip_allocation_policy {

  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  networking_mode = "VPC_NATIVE"

  release_channel {
    channel = "UNSPECIFIED"
  }
}

resource "google_container_node_pool" "configuration-gke-cluster-node-pool" {
  name       = "${google_container_cluster.configuration-gke-cluster.name}-node-pool"
  location   = var.google_region
  cluster    = google_container_cluster.configuration-gke-cluster.name
  node_count = var.configuration_gke_cluster_node_pool_size
  project    = var.google_project_id
  version    = data.google_container_engine_versions.gke-version.latest_node_version

  management {
    auto_repair  = true
    auto_upgrade = false
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]

    labels = {
      env = var.google_project_id
    }

    machine_type = "n1-standard-2"
    tags         = ["gke-node", "${var.google_project_id}-gke"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

output "kubernetes_cluster_name" {
  value       = google_container_cluster.configuration-gke-cluster.name
  description = "GKE Cluster Name"
}
