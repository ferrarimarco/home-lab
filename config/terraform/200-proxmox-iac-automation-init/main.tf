locals {
  base_directory_path         = "${path.module}/.."
  environments_directory_path = "${local.base_directory_path}/environments"
  templates_directory_path    = "${path.module}/templates"
}
