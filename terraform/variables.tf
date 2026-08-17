variable "resource_group_name" {
  description = "Must match Lab 07 exactly - case-sensitive."
  type        = string
  default     = "RG-FileServerLab"
}

variable "vm_name" {
  description = "Must match Lab 07 exactly - case-sensitive."
  type        = string
  default     = "FS01"
}

# No defaults on purpose. If these are blank, Terraform stops and yells at you
# instead of quietly assigning roles to nothing.
# These are Object IDs of Service Principals (see scripts/00-create-test-users.ps1),
# standing in for the SysAdmin/SupportTech/Auditor personas.
variable "sysadmin_object_id" {
  description = "Object ID of the SysAdmin service principal - receives Owner role on FS01."
  type        = string
}

variable "support_user_object_id" {
  description = "Object ID of the SupportTech service principal - receives VM Contributor role on FS01."
  type        = string
}

variable "auditor_object_id" {
  description = "Object ID of the Auditor service principal - receives Reader role on FS01."
  type        = string
}