$ErrorActionPreference = 'Stop'

$subscriptionId = $env:ARM_SUBSCRIPTION_ID
$prefix = $env:TF_VAR_name_prefix
$location = $env:TF_VAR_location

if ([string]::IsNullOrWhiteSpace($subscriptionId)) {
    throw 'ARM_SUBSCRIPTION_ID is required.'
}

if ([string]::IsNullOrWhiteSpace($prefix)) {
    $prefix = 'jd-alz'
}

if ([string]::IsNullOrWhiteSpace($location)) {
    $location = 'East US'
}

function Test-TerraformState([string]$address) {
    $state = & terraform state list 2>$null
    return ($state -contains $address)
}

function Import-IfExists([string]$address, [string]$resourceId) {
    if (Test-TerraformState $address) {
        Write-Host "Already managed: $address"
        return
    }

    $existingId = & az resource show --ids $resourceId --query id --output tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($existingId)) {
        Write-Host "Adopting existing resource: $address"
        & terraform import $address $existingId
        if ($LASTEXITCODE -ne 0) {
            throw "terraform import failed for $address"
        }
    }
    else {
        Write-Host "Not present in Azure; Terraform will create: $address"
    }
}

$networkRg = "$prefix-network-rg"
$monitoringRg = "$prefix-monitoring-rg"
$recoveryRg = "$prefix-recovery-rg"
$identityRg = "$prefix-identity-rg"
$vnetName = "$prefix-hub-vnet"
$firewallPip = "$prefix-firewall-pip"
$bastionPip = "$prefix-bastion-pip"
$firewallPolicy = "$prefix-firewall-policy"
$firewall = "$prefix-firewall"
$bastion = "$prefix-bastion"
$law = "$prefix-law"
$rsv = "$prefix-rsv"
$uami = "$prefix-uami"

$subBase = "/subscriptions/$subscriptionId"

Import-IfExists 'azurerm_resource_group.platform["network"]' "$subBase/resourceGroups/$networkRg"
Import-IfExists 'azurerm_resource_group.platform["monitoring"]' "$subBase/resourceGroups/$monitoringRg"
Import-IfExists 'azurerm_resource_group.platform["recovery"]' "$subBase/resourceGroups/$recoveryRg"
Import-IfExists 'azurerm_resource_group.platform["identity"]' "$subBase/resourceGroups/$identityRg"

$vnetId = "$subBase/resourceGroups/$networkRg/providers/Microsoft.Network/virtualNetworks/$vnetName"
Import-IfExists 'azurerm_virtual_network.hub' $vnetId

Import-IfExists 'azurerm_subnet.firewall' "$vnetId/subnets/AzureFirewallSubnet"
Import-IfExists 'azurerm_subnet.bastion' "$vnetId/subnets/AzureBastionSubnet"
Import-IfExists 'azurerm_subnet.gateway' "$vnetId/subnets/GatewaySubnet"

Import-IfExists 'azurerm_public_ip.firewall' "$subBase/resourceGroups/$networkRg/providers/Microsoft.Network/publicIPAddresses/$firewallPip"
Import-IfExists 'azurerm_public_ip.bastion' "$subBase/resourceGroups/$networkRg/providers/Microsoft.Network/publicIPAddresses/$bastionPip"
Import-IfExists 'azurerm_firewall_policy.hub' "$subBase/resourceGroups/$networkRg/providers/Microsoft.Network/firewallPolicies/$firewallPolicy"
Import-IfExists 'azurerm_firewall.hub' "$subBase/resourceGroups/$networkRg/providers/Microsoft.Network/azureFirewalls/$firewall"
Import-IfExists 'azurerm_bastion_host.hub' "$subBase/resourceGroups/$networkRg/providers/Microsoft.Network/bastionHosts/$bastion"
Import-IfExists 'azurerm_log_analytics_workspace.platform' "$subBase/resourceGroups/$monitoringRg/providers/Microsoft.OperationalInsights/workspaces/$law"
Import-IfExists 'azurerm_recovery_services_vault.platform' "$subBase/resourceGroups/$recoveryRg/providers/Microsoft.RecoveryServices/vaults/$rsv"
Import-IfExists 'azurerm_user_assigned_identity.platform' "$subBase/resourceGroups/$identityRg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$uami"

Write-Host 'Existing-resource adoption completed.'
