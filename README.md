# Azure Landing Zone - Terraform

Enterprise-oriented Azure Landing Zone foundation for a single Azure Pay-As-You-Go subscription, initially targeting East US.

## Scope

Phase 1 provisions a subscription-scoped foundation:

- Resource groups for platform network, monitoring, security, and recovery
- Hub VNet with reserved Firewall, Bastion, and Gateway subnets
- Azure Firewall Standard
- Azure Bastion Standard
- Log Analytics workspace
- Recovery Services vault
- Subscription-level managed identity
- Optional allowed-locations governance policy
- GitHub Actions validation

No subscription ID, credentials, state file, or secrets are stored in Git.

## Directory layout

```text
.
├── environments/
│   └── eastus/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars.example
├── modules/
│   └── README.md
├── .github/workflows/terraform-validate.yml
├── docs/architecture.md
├── .gitignore
└── README.md
```

## Prerequisites

- Azure CLI
- Terraform >= 1.9
- Azure subscription with sufficient permissions

## Deploy

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
export TF_VAR_subscription_id="<SUBSCRIPTION_ID>"

cd environments/eastus
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -out tfplan
terraform apply tfplan
```

For PowerShell:

```powershell
$env:TF_VAR_subscription_id = "<SUBSCRIPTION_ID>"
```

The default deployment region is `East US`.

## Next phases

1. Management groups and Azure Policy hierarchy
2. Hub-and-spoke networking and route tables
3. Private DNS and Private Endpoints
4. Identity/RBAC and Defender for Cloud
5. Workload spokes for application/data tiers
6. Azure Virtual WAN, VPN and ExpressRoute where required
7. Remote state and federated GitHub Actions authentication
