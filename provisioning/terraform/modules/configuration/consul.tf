resource "tls_private_key" "consul-ca" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "tls_self_signed_cert" "consul-ca" {
  key_algorithm   = tls_private_key.consul-ca.algorithm
  private_key_pem = tls_private_key.consul-ca.private_key_pem

  subject {
    common_name  = "consul-ca.local"
    organization = "ferrari.how"
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
  algorithm = "RSA"
  rsa_bits  = "4096"
}

# Create the request to sign the cert with the CA
resource "tls_cert_request" "consul-req" {
  key_algorithm   = tls_private_key.consul-private-key.algorithm
  private_key_pem = tls_private_key.consul-private-key.private_key_pem

  dns_names = [
    "consul",
    "consul.local",
    "consul.default.svc.cluster.local",
    "server.${var.consul_datacenter_name}.consul",
  ]

  ip_addresses = [
    "localhost",
    "127.0.0.1"
  ]

  subject {
    common_name  = "consul.local"
    organization = "ferrari.how"
  }
}

resource "tls_locally_signed_cert" "consul-signed-cert" {
  cert_request_pem = tls_cert_request.consul-req.cert_request_pem

  ca_key_algorithm   = tls_private_key.consul-ca.algorithm
  ca_private_key_pem = tls_private_key.consul-ca.private_key_pem
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

resource "kubernetes_secret" "consul-certs" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name      = "consul-certs"
    namespace = kubernetes_namespace.consul.metadata.0.name
  }

  data = {
    "ca.pem"         = tls_self_signed_cert.consul-ca.cert_pem
    "consul.pem"     = tls_locally_signed_cert.consul-signed-cert.cert_pem
    "consul-key.pem" = tls_private_key.consul-private-key.private_key_pem
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
    namespace = kubernetes_namespace.consul.metadata.0.name
  }

  data = {
    (local.consul_gossip_key_secret_key) = random_id.consul_encrypt.b64_std
  }

  type = "Opaque"
}

locals {
  consul_namespace_name         = "consul"
  consul_release_name           = "configuration-consul"
  consul_gossip_key_secret_name = "consul-gossip-key"
  consul_gossip_key_secret_key  = "gossipkey"
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
}
