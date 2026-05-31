resource "local_file" "proxmox_host_secrets_pve1" {

  content = templatefile(
    local.proxmox_host_secrets_tfvars_template_path,
    {
      proxmox_virtual_environment_api_token = module.proxmox-iam-automation-pve1.terraform_automation_writer_api_token.value,
    }
  )
  file_permission = "0644"
  filename        = "${local.environments_directory_path}/proxmox-${var.proxmox_virtual_environment_node_hostname}-secrets.tfvars"
}
