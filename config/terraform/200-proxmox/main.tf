locals {
  base_directory_path                          = "${path.module}/.."
  environments_directory_path                  = "${local.base_directory_path}/environments"
  proxmox_host_secrets_tfvars_destination_path = "${local.environments_directory_path}/proxmox-${var.proxmox_virtual_environment_node_hostname}-secrets.tfvars"

  templates_directory_path                  = "${path.module}/templates"
  terraform_templates_directory_path        = "${local.templates_directory_path}/terraform"
  proxmox_host_secrets_tfvars_template_path = "${local.terraform_templates_directory_path}/proxmox-host-secrets.tfvars.tftpl"
}

data "proxmox_virtual_environment_node" "node" {
  node_name = var.proxmox_virtual_environment_node_hostname
}
