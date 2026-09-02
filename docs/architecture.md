# Azure Landing Zone Architecture

## Phase 1: single-subscription East US foundation

```text
Azure Tenant
    |
    +-- Pay-As-You-Go Subscription
            |
            +-- Platform Network RG
            |     +-- Hub VNet 10.0.0.0/16
            |     +-- AzureFirewallSubnet 10.0.0.0/24
            |     +-- AzureBastionSubnet 10.0.1.0/26
            |     +-- GatewaySubnet 10.0.2.0/24
            |     +-- Azure Firewall Standard
            |     +-- Azure Bastion Standard
            |
            +-- Monitoring RG
            |     +-- Log Analytics Workspace
            |
            +-- Recovery RG
            |     +-- Recovery Services Vault
            |
            +-- Identity RG
                  +-- User Assigned Managed Identity
```

## Design principles

- Separate platform resources from workload resources.
- Keep the hub VNet centrally managed.
- Reserve the gateway subnet for future VPN or ExpressRoute connectivity.
- Use Azure Firewall for centralized network inspection when spoke routing is introduced.
- Use Bastion for administrative access without exposing workload VMs directly to the Internet.
- Centralize platform logs in Log Analytics.
- Keep subscription identifiers and credentials outside source control.

## Planned phase 2

- Management group hierarchy where tenant permissions allow it
- Azure Policy initiatives and assignments
- Hub-to-spoke peering
- Azure Firewall route tables and forced tunneling patterns
- Private DNS zones and Private Endpoints
- Defender for Cloud integration
- RBAC groups and least-privilege assignments
- Workload spokes for app, data, and management tiers
