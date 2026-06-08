locals {
  base_terraform_directory = "${path.module}/.."

  local_templates_directory_path           = "${path.module}/templates"
  local_terraform_templates_directory_path = "${local.local_templates_directory_path}/terraform"

  local_backend_template        = "${local.local_terraform_templates_directory_path}//backend-local.tf.tftpl"
  local_backend_config_template = "${local.local_terraform_templates_directory_path}/config.local.tfbackend.tftpl"

  terraform_proxmox_providers_template = "${local.local_terraform_templates_directory_path}/proxmox-providers.tf.tftpl"

  core_backend_directories = toset([for _, version_file in local.core_versions_files : trimprefix(trimsuffix(version_file, "/versions.tf"), "../")])

  all_versions_files    = fileset(local.base_terraform_directory, "**/versions.tf")
  module_versions_files = fileset(local.base_terraform_directory, "modules/**/versions.tf")

  core_versions_files = setsubtract(local.all_versions_files, local.module_versions_files)
}

resource "local_file" "local_backend" {
  for_each = local.core_backend_directories

  content = templatefile(
    local.local_backend_template,
    {}
  )
  file_permission = "0644"
  filename        = "${local.base_terraform_directory}/${each.key}/backend-local.tf"
}


resource "local_file" "local_backend_config" {
  for_each = local.core_backend_directories

  content = templatefile(
    local.local_backend_config_template,
    {
      path = "../environments/backend/local/${each.key}/terraform.tfstate",
    }
  )
  file_permission = "0644"
  filename        = "${path.module}/../environments/backend-config/local/${each.key}.local.tfbackend"
}

resource "local_file" "proxmox_terraform_providers" {
  # Filter out '000-initialize' to avoid configuring a proxmox provider because
  # the initialize module doesn't need it
  for_each = {
    for k, v in local.core_backend_directories : k => v
    if k != "000-initialization"
  }

  content = templatefile(
    local.terraform_proxmox_providers_template,
    {
      proxmox_hosts = keys(var.proxmox_virtual_environment_hosts),
    }
  )
  file_permission = "0644"
  filename        = "${local.base_terraform_directory}/${each.key}/providers.tf"
}
