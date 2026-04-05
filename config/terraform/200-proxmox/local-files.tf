resource "local_file" "proxmox_host_secrets" {

  content = templatefile(
    local.proxmox_host_secrets_tfvars_template_path,
    {
      proxmox_virtual_environment_api_token = proxmox_user_token.terraform_automation_writer_api_token.value,
    }
  )
  file_permission = "0644"
  filename        = local.proxmox_host_secrets_tfvars_destination_path
}
