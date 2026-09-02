locals {
  prefix = lower(replace(var.name_prefix, " ", "-"))

  resource_groups = {
    network    = "${local.prefix}-network-rg"
    monitoring = "${local.prefix}-monitoring-rg"
    recovery   = "${local.prefix}-recovery-rg"
    identity   = "${local.prefix}-identity-rg"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "platform" {
  for_each = local.resource_groups

  name     = each.value
  location = var.location
  tags     = var.common_tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "${local.prefix}-hub-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform["network"].name
  address_space       = var.hub_address_space
  tags                = var.common_tags
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.platform["network"].name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.platform["network"].name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.platform["network"].name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_public_ip" "firewall" {
  name                = "${local.prefix}-firewall-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform["network"].name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.common_tags
}

resource "azurerm_firewall_policy" "hub" {
  name                = "${local.prefix}-firewall-policy"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform["network"].name
  sku                 = "Standard"
  tags                = var.common_tags
}

resource "azurerm_firewall" "hub" {
  name                = "${local.prefix}-firewall"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform["network"].name
  sku_name            = "AZFW_VNet"
  sku_tier             = "Standard"
  firewall_policy_id   = azurerm_firewall_policy.hub.id

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = var.common_tags
}

resource "azurerm_public_ip" "bastion" {
  name                = "${local.prefix}-bastion-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform["network"].name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  tags                = var.common_tags
}

resource "azurerm_bastion_host" "hub" {
  name                   = "${local.prefix}-bastion"
  location               = var.location
  resource_group_name    = azurerm_resource_group.platform["network"].name
  sku                    = "Standard"
  copy_paste_enabled     = true
  file_copy_enabled      = false
  ip_connect_enabled     = true
  shareable_link_enabled = false
  tunneling_enabled      = true

  ip_configuration {
    name                 = "primary"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.common_tags
}

resource "azurerm_log_analytics_workspace" "platform" {
  name                = "${local.prefix}-law"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform["monitoring"].name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.common_tags
}

resource "azurerm_recovery_services_vault" "platform" {
  name                = "${local.prefix}-rsv"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform["recovery"].name
  sku                 = "Standard"
  soft_delete_enabled = true
  tags                = var.common_tags
}

resource "azurerm_user_assigned_identity" "platform" {
  name                = "${local.prefix}-uami"
  location            = var.location
  resource_group_name = azurerm_resource_group.platform["identity"].name
  tags                = var.common_tags
}

resource "azurerm_role_assignment" "platform_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id
}
