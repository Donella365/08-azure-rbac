# principal_type = "ServicePrincipal" on all three: our test identities are
# service principals (see scripts/00-create-test-users.ps1), not human users.
# Setting this explicitly avoids "principal not found" errors that can happen
# if Terraform tries to assign the role before Entra ID has fully replicated
# the new identity everywhere.

# Owner: full control on FS01, including the power to assign or remove
# other identities' roles on this VM. Nothing outside FS01 is touched.
resource "azurerm_role_assignment" "sysadmin_owner" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Owner"
  principal_id         = var.sysadmin_object_id
  principal_type       = "ServicePrincipal"
}

# Virtual Machine Contributor: start, stop, restart, connect.
# Cannot delete FS01. Cannot touch RBAC assignments.
resource "azurerm_role_assignment" "supporttech_vm_contributor" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = var.support_user_object_id
  principal_type       = "ServicePrincipal"
}

# Reader: can look at FS01's settings and status. Cannot start, stop,
# delete, or change anything.
resource "azurerm_role_assignment" "auditor_reader" {
  scope                = data.azurerm_virtual_machine.fs01.id
  role_definition_name = "Reader"
  principal_id         = var.auditor_object_id
  principal_type       = "ServicePrincipal"
}