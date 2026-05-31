locals {
  base_directory_path         = "${path.module}/.."
  environments_directory_path = "${local.base_directory_path}/environments"

  templates_directory_path                  = "${path.module}/templates"
  terraform_templates_directory_path        = "${local.templates_directory_path}/terraform"
  proxmox_host_secrets_tfvars_template_path = "${local.terraform_templates_directory_path}/proxmox-host-secrets.tfvars.tftpl"
}
