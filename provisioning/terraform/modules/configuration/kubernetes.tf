provider "kubernetes" {
  alias            = "configuration-gke-cluster"
  load_config_file = false

  host  = "https://${google_container_cluster.configuration-gke-cluster.endpoint}"
  token = data.google_container_cluster.configuration-gke-cluster.access_token

  cluster_ca_certificate = base64decode(google_container_cluster.configuration-gke-cluster.master_auth[0].cluster_ca_certificate,
  )
}
