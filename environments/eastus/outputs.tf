output "subscription_id" {
  description = "Subscription targeted by the landing zone."
  value       = var.subscription_id
  sensitive   = true
}

output "resource_groups" {
  description = "Platform resource groups."
  value       = { for k, v in azurerm_resource_group.platform : k => v.name }
}

output "hub_vnet_id" {
  description = "Hub VNet resource ID."
  value       = azurerm_virtual_network.hub.id
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP."
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "bastion_id" {
  description = "Azure Bastion resource ID."
  value       = azurerm_bastion_host.hub.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.platform.id
}
