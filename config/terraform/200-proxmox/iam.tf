resource "proxmox_virtual_environment_role" "terraform_automation_writer" {
  role_id = "terraform-automation-writer"
  privileges = [
    "Datastore.Audit",
    "VM.Audit",
    "VM.Config.Disk",
    "VM.Monitor",
    "Sys.Audit",
  ]
}

resource "proxmox_acl" "terraform_automation_writer_user_token" {
  path     = "/"
  role_id  = proxmox_virtual_environment_role.terraform_automation_writer.role_id
  token_id = proxmox_user_token.terraform_automation_writer_api_token.id
}

resource "proxmox_virtual_environment_user" "terraform_automation_writer" {
  acl {
    path      = "/"
    propagate = true
    role_id   = proxmox_virtual_environment_role.terraform_automation_writer.role_id
  }

  comment = "Managed by Terraform"
  user_id = "terraform-automation-writer@pam"
}

resource "proxmox_user_token" "terraform_automation_writer_api_token" {
  token_name = "terraform-automation-writer"
  user_id    = proxmox_virtual_environment_user.terraform_automation_writer.user_id
}
