data "kubernetes_secret" "consul-ca-cert" {
  depends_on = [
    helm_release.configuration-consul
  ]

  metadata {
    name      = "${local.consul_release_name}-ca-cert"
    namespace = local.consul_namespace_name
  }

  provider = kubernetes.configuration-gke-cluster
}

data "kubernetes_secret" "consul-server-cert" {
  depends_on = [
    helm_release.configuration-consul
  ]

  metadata {
    name      = "${local.consul_release_name}-server-cert"
    namespace = local.consul_namespace_name
  }

  provider = kubernetes.configuration-gke-cluster
}

data "kubernetes_secret" "consul-bootstrap-acl-token" {
  depends_on = [
    helm_release.configuration-consul
  ]

  metadata {
    name      = "${local.consul_release_name}-bootstrap-acl-token"
    namespace = local.consul_namespace_name
  }

  provider = kubernetes.configuration-gke-cluster
}

provider "consul" {
  address    = local.consul_dns_name
  ca_pem     = data.kubernetes_secret.consul-ca-cert.data["tls.crt"]
  cert_pem   = data.kubernetes_secret.consul-server-cert.data["tls.crt"]
  key_pem    = data.kubernetes_secret.consul-server-cert.data["tls.key"]
  datacenter = var.consul_datacenter_name
  scheme     = "https"
  token      = data.kubernetes_secret.consul-bootstrap-acl-token.data["token"]
}
