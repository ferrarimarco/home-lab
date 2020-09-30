resource "kubernetes_namespace" "consul" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name = local.consul_namespace_name
  }
}

locals {
  # Remove the last dot because it's in the DNS record
  consul_dns_name       = trimsuffix(google_dns_record_set.main-zone-consul-a.name, ".")
  consul_namespace_name = "consul"

  consul_release_name = "configuration-consul"

  consul_gossip_key_secret_name = "${local.consul_release_name}-gossip-key"
  consul_gossip_key_secret_key  = "gossipkey"

  consul_server_additional_dns_sans = [
    local.consul_dns_name
  ]

  consul_managed_certificate_name = "${local.consul_release_name}-managed-certificate"
  consul_ui_backendconfig_name    = "${local.consul_release_name}-ui-backendconfig"
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
    templatefile("${path.module}/helm/configuration-consul-values.yaml", {
      consul_ui_backendconfig_name  = local.consul_ui_backendconfig_name,
      consul_datacenter_name        = var.consul_datacenter_name,
      consul_release_name           = local.consul_release_name,
      consul_gossip_key_secret_key  = local.consul_gossip_key_secret_key,
      consul_gossip_key_secret_name = local.consul_gossip_key_secret_name
    }),
  ]

  dynamic "set" {
    for_each = local.consul_server_additional_dns_sans
    content {
      name  = "global.tls.serverAdditionalDNSSANs[${set.key}]"
      value = set.value
    }
  }

  depends_on = [
    kubernetes_secret.consul-gossip-key
  ]
}

resource "google_compute_global_address" "consul_ingress_global_address" {
  name    = "${local.consul_release_name}-ip"
  project = var.google_project_id
}

resource "google_dns_record_set" "main-zone-consul-a" {
  managed_zone = google_dns_managed_zone.main-dns-zone.name
  name         = "consul.${google_dns_managed_zone.main-dns-zone.dns_name}"
  project      = var.google_project_id
  rrdatas = [
    google_compute_global_address.consul_ingress_global_address.address
  ]
  type = "A"
  ttl  = 300
}

resource "kubernetes_manifest" "consul-managed-certificate" {
  depends_on = [
    google_dns_record_set.main-zone-consul-a,
    helm_release.configuration-consul
  ]

  manifest = {
    "apiVersion" = "networking.gke.io/v1beta2"
    "kind"       = "ManagedCertificate"
    "metadata" = {
      "name"      = local.consul_managed_certificate_name
      "namespace" = local.consul_namespace_name
    }
    "spec" = {
      "domains" = local.consul_server_additional_dns_sans
    }
  }

  provider = kubernetes-alpha.configuration-gke-cluster-alpha
}

resource "kubernetes_manifest" "consul-ui-backendconfig" {
  depends_on = [
    google_dns_record_set.main-zone-consul-a,
    helm_release.configuration-consul
  ]

  manifest = {
    "apiVersion" = "cloud.google.com/v1"
    "kind"       = "BackendConfig"
    "metadata" = {
      "name"      = local.consul_ui_backendconfig_name
      "namespace" = local.consul_namespace_name
    }
    "spec" = {
      "healthCheck" = {
        "requestPath" = "/ui/"
      }
    }
  }

  provider = kubernetes-alpha.configuration-gke-cluster-alpha
}

resource "kubernetes_ingress" "consul_ingress" {
  metadata {
    annotations = {
      "kubernetes.io/ingress.allow-http"            = false
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.consul_ingress_global_address.name
      "networking.gke.io/managed-certificates"      = join(",", [local.consul_managed_certificate_name])
    }

    name      = "${local.consul_release_name}-ui-ingress"
    namespace = local.consul_namespace_name
  }

  provider = kubernetes.configuration-gke-cluster

  spec {
    rule {
      host = local.consul_dns_name
      http {
        path {
          backend {
            service_name = "${local.consul_release_name}-ui"
            service_port = "https"
          }

          path = "/ui/*"
        }
      }
    }
  }

  depends_on = [
    google_dns_record_set.main-zone-consul-a,
    helm_release.configuration-consul,
    kubernetes_manifest.consul-managed-certificate,
    kubernetes_manifest.consul-ui-backendconfig
  ]
}
