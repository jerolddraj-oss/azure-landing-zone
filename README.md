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
- Jenkins-based Terraform CI/CD

No subscription ID, credentials, state file, or secrets are stored in Git.

## Directory layout

```text
.
├── Jenkinsfile
├── environments/
│   └── eastus/
│       ├── backend.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars.example
├── modules/
│   └── README.md
├── scripts/
│   └── adopt-existing.ps1
├── docs/
│   ├── architecture.md
│   └── jenkins-cicd.md
├── .gitignore
└── README.md
```

## CI/CD

Jenkins is the authoritative CI/CD pipeline for this repository. GitHub is used for source control and pull-request collaboration.

The pipeline in `Jenkinsfile` performs:

1. Terraform format check
2. Azure authentication using Jenkins-managed credentials
3. Bootstrap of the Azure Storage remote-state location
4. Terraform initialization using the `azurerm` backend
5. Adoption of already-existing Azure resources when necessary
6. Terraform validation
7. Terraform plan
8. Manual approval for `APPLY` and `DESTROY`
9. Terraform apply/destroy using the reviewed plan
10. Workspace cleanup

GitHub Actions is intentionally not used for deployment or validation in this design.

See [docs/jenkins-cicd.md](docs/jenkins-cicd.md) for Jenkins setup and Azure credential requirements.

## Prerequisites

For local execution:

- Azure CLI
- Terraform >= 1.9
- Azure subscription with sufficient permissions

For Jenkins execution, the Windows Jenkins agent needs Git, Terraform, Azure CLI, and PowerShell. The required Jenkins credentials are documented in `docs/jenkins-cicd.md`.

## Local deployment

For Jenkins, use the `PLAN` action first. For local testing, authenticate with Azure CLI and configure the Terraform backend before running Terraform.

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"
export TF_VAR_subscription_id="<SUBSCRIPTION_ID>"

cd environments/eastus
terraform init \
  -backend-config="storage_account_name=<STATE_STORAGE_ACCOUNT>" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=jd-alz-eastus.tfstate"
terraform fmt -check -recursive
terraform validate
terraform plan -out tfplan
```

For PowerShell:

```powershell
$env:TF_VAR_subscription_id = "<SUBSCRIPTION_ID>"
```

The default deployment region is `East US`.

## Terraform state

Terraform state is now stored remotely in Azure Blob Storage using the `azurerm` backend. This prevents the state from disappearing when a Jenkins workspace is cleaned and provides backend locking for concurrent Terraform operations.

Jenkins bootstraps a dedicated state resource group and storage account automatically. If the derived storage-account name is unavailable because Azure Storage names are globally unique, provide a unique value through the Jenkins `TFSTATE_STORAGE_ACCOUNT` parameter.

The current implementation uses an Azure Storage access key through `ARM_ACCESS_KEY` as a transitional measure. The preferred production design is Microsoft Entra/OIDC authentication with least-privilege Storage Blob Data Contributor access.

## Recovery from the previous failed deployment

The previous Jenkins run used local Terraform state. Jenkins then cleaned the workspace, so the resources created during that run were no longer represented in Terraform state. The new pipeline imports existing landing-zone resources before planning, allowing the resources to be brought under Terraform management without deleting them first.

The subscription-level Reader role assignment is disabled by default because the Jenkins service principal currently lacks Azure RBAC `roleAssignments/write` permission. It can be enabled later after the appropriate Azure RBAC permission is deliberately granted.

## Next phases

1. Move Jenkins Azure authentication to workload identity federation/OIDC
2. Replace the transitional storage access-key backend authentication with Entra ID
3. Add management groups and Azure Policy hierarchy
4. Add hub-and-spoke networking and route tables
5. Add Private DNS and Private Endpoints
6. Add Identity/RBAC and Defender for Cloud
7. Add workload spokes for application/data tiers
8. Add Azure Virtual WAN, VPN and ExpressRoute where required
9. Add TFLint/Checkov and stronger Jenkins security gates
