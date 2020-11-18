resource "kubernetes_namespace" "opentelemetry" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name = local.opentelemetry_namespace_name
  }
}

locals {
  opentelemetry_namespace_name = "opentelemetry"
}

resource "helm_release" "opentelemetry_collector" {
  name       = "opentelemetry-collector"
  namespace  = local.opentelemetry_namespace_name
  provider   = helm.configuration-gke-cluster
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  version    = var.opentelemetry_collector_chart_version

  values = [
    templatefile("${path.module}/helm/opentelemetry-collector-values.yaml", {
      prometheus_configuration = var.opentelemetry_collector_prometheus_exporter_endpoints_configuration
    }),
  ]
}
