provider "kubernetes" {
  load_config_file = false

  host  = "https://${google_container_cluster.configuration-gke-cluster.endpoint}"
  token = provider.google.access_token

  cluster_ca_certificate = base64decode(google_container_cluster.configuration-gke-cluster.master_auth[0].cluster_ca_certificate,
  )
}
