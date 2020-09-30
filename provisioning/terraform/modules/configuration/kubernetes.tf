provider "kubernetes" {
  alias            = "configuration-gke-cluster"
  load_config_file = false

  host  = "https://${google_container_cluster.configuration-gke-cluster.endpoint}"
  token = data.google_client_config.google-provider-configuration.access_token

  cluster_ca_certificate = base64decode(google_container_cluster.configuration-gke-cluster.master_auth[0].cluster_ca_certificate)
}

provider "kubernetes-alpha" {
  alias = "configuration-gke-cluster-alpha"

  host  = "https://${google_container_cluster.configuration-gke-cluster.endpoint}"
  token = data.google_client_config.google-provider-configuration.access_token

  cluster_ca_certificate = base64decode(google_container_cluster.configuration-gke-cluster.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_cluster_role_binding" "cloud-build-cluster-admin-binding" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    annotations = {
      "rbac.authorization.kubernetes.io/autoupdate" = "true"
    }
    name = "cloud-build-cluster-admin-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind = "User"
    name = var.cloud_build_service_account_id
  }
}
