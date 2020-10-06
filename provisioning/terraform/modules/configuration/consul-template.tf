resource "consul_acl_policy" "consul-template" {
  name  = "consul-template"
  rules = <<-RULE
    key_prefix "" {
      policy = "read"
    }
    node_prefix "" {
      policy = "read"
    }
    service_prefix "" {
      policy = "read"
    }
    RULE
}

resource "consul_acl_token" "consul-template" {
  description = "consul-template token"
  policies    = [consul_acl_policy.consul-template.name]
  local       = true
}

data "consul_acl_token_secret_id" "consul-template-secret-id" {
  accessor_id = consul_acl_token.consul-template.accessor_id
}

resource "google_storage_bucket_object" "consul-template-configuration" {
  name    = "${var.consul_template_directory_path}/config.hcl"
  bucket  = var.configuration_bucket_name
  content = templatefile("${path.module}/templates/consul-template-config.hcl.tpl", { consul_address = local.consul_dns_name, consul_template_token = data.consul_acl_token_secret_id.consul-template-secret-id.secret_id })
}
