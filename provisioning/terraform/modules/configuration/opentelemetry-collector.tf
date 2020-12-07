resource "kubernetes_namespace" "opentelemetry" {
  provider = kubernetes.configuration-gke-cluster

  metadata {
    name = local.opentelemetry_namespace_name
  }
}

locals {
  opentelemetry_namespace_name                  = "opentelemetry"
  opentelemetry_kubernetes_service_account_name = "opentelemetry-collector"
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
      service_account_annotations = {
        "iam.gke.io/gcp-service-account" = var.iot_core_telemetry_destination_bucket_read_only_service_account.email
      }
      service_account_name = local.opentelemetry_kubernetes_service_account_name
    }),
  ]
}

resource "google_service_account_iam_binding" "iot_core_telemetry_destination_bucket_workload_identity_binding" {
  service_account_id = var.iot_core_telemetry_destination_bucket_read_only_service_account.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.google_project_id}.svc.id.goog[${helm_release.opentelemetry_collector.namespace}/${local.opentelemetry_kubernetes_service_account_name}]",
  ]
}
