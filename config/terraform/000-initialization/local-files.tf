locals {
  base_terraform_directory      = "${path.module}/.."
  local_backend_template        = "${path.module}/templates/terraform/backend-local.tf.tftpl"
  local_backend_config_template = "${path.module}/templates/terraform/config.local.tfbackend.tftpl"

  core_backend_directories = toset([for _, version_file in local.core_versions_files : trimprefix(trimsuffix(version_file, "/versions.tf"), "../")])
  core_versions_files      = flatten([for _, file in flatten(fileset(local.base_terraform_directory, "**/versions.tf")) : file])
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
