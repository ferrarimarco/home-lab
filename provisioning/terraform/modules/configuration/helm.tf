provider "helm" {
  alias = "configuration-gke-cluster"

  kubernetes {
    host  = google_container_cluster.configuration-gke-cluster.endpoint
    token = data.google_container_cluster.configuration-gke-cluster.access_token

    client_certificate     = base64decode(google_container_cluster.configuration-gke-cluster.master_auth.0.client_certificate)
    client_key             = base64decode(google_container_cluster.configuration-gke-cluster.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.configuration-gke-cluster.master_auth.0.cluster_ca_certificate)
  }
}
