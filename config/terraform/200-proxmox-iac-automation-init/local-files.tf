locals {
  compiled_secrets = {
    pve1 = {
      api_token = module.proxmox-iam-automation-pve1.terraform_automation_writer_api_token.value
    }
  }
}

resource "local_file" "proxmox_secrets" {
  # jsonencode perfectly formats the nested map of objects automatically
  content = jsonencode({
    proxmox_virtual_environment_hosts_secrets = local.compiled_secrets
  })

  file_permission = "0600"

  filename = "${local.environments_directory_path}/proxmox-secrets.tfvars.json"
}
