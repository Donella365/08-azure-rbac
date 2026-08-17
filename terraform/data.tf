# Reads Lab 07's resource group. Does not create or change anything.
data "azurerm_resource_group" "lab" {
  name = var.resource_group_name
}

# Reads FS01 by name. This gives us FS01's full Azure resource ID,
# which is the exact scope every role assignment below points at.
#
# Scoping to this VM's ID = the role applies to FS01 only.
# Scoping to the resource group ID instead = the role would silently
# apply to DC01 and CLIENT01 too. Always double check the scope line.
data "azurerm_virtual_machine" "fs01" {
  name                = var.vm_name
  resource_group_name = data.azurerm_resource_group.lab.name
}
