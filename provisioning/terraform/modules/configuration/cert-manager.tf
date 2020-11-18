resource "kubernetes_namespace" "cert_manager" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name = local.cert_manager_namespace_name
  }
}

locals {
  cert_manager_namespace_name = "cert-manager"
  cert_manager_release_name   = local.cert_manager_namespace_name
}

resource "helm_release" "cert-manager" {
  name       = local.cert_manager_release_name
  namespace  = local.cert_manager_namespace_name
  provider   = helm.configuration-gke-cluster
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_chart_version

  set {
    name  = "installCRDs"
    value = "true"
  }

}
