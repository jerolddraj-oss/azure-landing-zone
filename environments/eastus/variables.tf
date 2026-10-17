variable "subscription_id" {
  description = "Target Azure subscription ID. Supply through TF_VAR_subscription_id."
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "East US"
}

variable "name_prefix" {
  description = "Resource naming prefix."
  type        = string
  default     = "jd-alz"
}

variable "hub_address_space" {
  description = "Hub VNet address space."
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition = length(var.hub_address_space) > 0 && alltrue([
      for cidr in var.hub_address_space : can(cidrhost(cidr, 0))
    ]) && tonumber(split("/", var.hub_address_space[0])[1]) <= 22
    error_message = "The first hub CIDR must be valid IPv4 with a prefix of /22 or larger so three /24 platform subnets can be reserved."
  }
}

variable "enable_platform_reader_assignment" {
  description = "Enable the subscription-level Reader assignment for the platform managed identity. Requires Microsoft.Authorization/roleAssignments/write permission for the Jenkins identity."
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default = {
    project     = "azure-landing-zone"
    environment = "platform"
    managed_by  = "terraform"
  }
}
