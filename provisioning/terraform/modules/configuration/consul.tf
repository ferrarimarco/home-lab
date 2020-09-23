resource "tls_private_key" "consul-ca-private-key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "consul-ca" {
  key_algorithm   = tls_private_key.consul-ca-private-key.algorithm
  private_key_pem = tls_private_key.consul-ca-private-key.private_key_pem

  subject {
    common_name    = var.tls_self_signed_cert_subject_common_name
    organization   = var.tls_self_signed_cert_subject_organization
    street_address = []
  }

  validity_period_hours = 8760
  is_ca_certificate     = true

  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "key_encipherment",
  ]
}

resource "tls_private_key" "consul-private-key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "consul-req" {
  key_algorithm   = tls_private_key.consul-private-key.algorithm
  private_key_pem = tls_private_key.consul-private-key.private_key_pem

  dns_names = [
    "consul",
    var.tls_self_signed_cert_subject_common_name,
    "${local.consul_release_name}-server",
    "${local.consul_release_name}-server.${local.consul_namespace_name}.svc",
    "consul.${local.consul_namespace_name}.svc.cluster.local",
    "server.${var.consul_datacenter_name}.consul",
  ]

  ip_addresses = [
    "127.0.0.1"
  ]

  subject {
    common_name    = var.tls_self_signed_cert_subject_common_name
    organization   = var.tls_self_signed_cert_subject_organization
    street_address = []
  }
}

resource "tls_locally_signed_cert" "consul-signed-cert" {
  cert_request_pem = tls_cert_request.consul-req.cert_request_pem

  ca_key_algorithm   = tls_private_key.consul-ca-private-key.algorithm
  ca_private_key_pem = tls_private_key.consul-ca-private-key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.consul-ca.cert_pem

  validity_period_hours = 8760

  allowed_uses = [
    "cert_signing",
    "client_auth",
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]
}

resource "kubernetes_namespace" "consul" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name = local.consul_namespace_name
  }
}

locals {
  consul_namespace_name = "consul"

  consul_release_name = "configuration-consul"

  consul_gossip_key_secret_name = "${local.consul_release_name}-gossip-key"
  consul_gossip_key_secret_key  = "gossipkey"

  consul_ca_certs_secret_name     = "${local.consul_release_name}-ca-cert"
  consul_ca_certs_certificate_key = "tls.crt" # (ca_file in Consul configuration) PEM-encoded certificate authority (CA)
  consul_ca_certs_private_key_key = "tls.key" # private key of the CA certificate

  consul_server_certs_secret_name     = "${local.consul_release_name}-server-cert"
  consul_server_certs_certificate_key = "tls.crt" # (cert_file in Consul configuration) PEM-encoded server certificate
  consul_server_certs_private_key_key = "tls.key" # (key_file in Consul configuration) PEM-encoded private key of the server certificate
}

resource "kubernetes_secret" "consul-ca-cert" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name      = local.consul_ca_certs_secret_name
    namespace = local.consul_namespace_name
  }

  data = {
    (local.consul_ca_certs_certificate_key) = tls_self_signed_cert.consul-ca.cert_pem
    (local.consul_ca_certs_private_key_key) = tls_private_key.consul-ca-private-key.private_key_pem
  }

  type = "Opaque"
}

resource "kubernetes_secret" "consul-server-cert" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name      = local.consul_server_certs_secret_name
    namespace = local.consul_namespace_name
  }

  data = {
    (local.consul_server_certs_certificate_key) = tls_locally_signed_cert.consul-signed-cert.cert_pem
    (local.consul_server_certs_private_key_key) = tls_private_key.consul-private-key.private_key_pem
  }

  type = "Opaque"
}

resource "random_id" "consul_encrypt" {
  byte_length = 16
}

resource "kubernetes_secret" "consul-gossip-key" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name      = local.consul_gossip_key_secret_name
    namespace = local.consul_namespace_name
  }

  data = {
    (local.consul_gossip_key_secret_key) = random_id.consul_encrypt.b64_std
  }

  type = "Opaque"

  depends_on = [
    kubernetes_namespace.consul
  ]
}

resource "helm_release" "configuration-consul" {
  name       = local.consul_release_name
  namespace  = local.consul_namespace_name
  provider   = helm.configuration-gke-cluster
  repository = "https://helm.releases.hashicorp.com"
  chart      = "consul"
  version    = var.consul_chart_version

  values = [
    file("${path.module}/helm/configuration-consul-values.yaml")
  ]

  set {
    name  = "global.datacenter"
    type  = "string"
    value = var.consul_datacenter_name
  }

  set {
    name  = "global.name"
    type  = "string"
    value = local.consul_release_name
  }

  set {
    name  = "global.gossipEncryption.secretName"
    type  = "string"
    value = local.consul_gossip_key_secret_name
  }

  set {
    name  = "global.gossipEncryption.secretKey"
    type  = "string"
    value = local.consul_gossip_key_secret_key
  }

  set {
    name  = "global.tls.caCert.secretName"
    type  = "string"
    value = local.consul_ca_certs_secret_name
  }

  set {
    name  = "global.tls.caCert.secretKey"
    type  = "string"
    value = local.consul_ca_certs_certificate_key
  }

  set {
    name  = "global.tls.caKey.secretName"
    type  = "string"
    value = local.consul_ca_certs_secret_name
  }

  set {
    name  = "global.tls.caKey.secretKey"
    type  = "string"
    value = local.consul_ca_certs_private_key_key
  }

  depends_on = [
    kubernetes_secret.consul-gossip-key,
    kubernetes_secret.consul-ca-cert,
    kubernetes_secret.consul-server-cert
  ]
}

# Workaround for https://github.com/hashicorp/consul-helm/issues/88
# The consul helm chart doesn't yet provide an Ingress
resource "kubernetes_ingress" "consul-ui-ingress" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name = "${local.consul_release_name}-ui-ingress"

    labels = {
      "app"       = local.consul_release_name
      "component" = "ui"
    }
  }

  spec {
    rule {
      http {
        path {
          backend {
            service_name = "${local.consul_release_name}-ui"
            service_port = 80
          }

          path = "/"
        }
      }
    }
  }

  depends_on = [
    helm_release.configuration-consul
  ]
}
