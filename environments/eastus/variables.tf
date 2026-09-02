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
