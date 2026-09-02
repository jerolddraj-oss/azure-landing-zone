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
- Jenkins-based Terraform CI/CD

No subscription ID, credentials, state file, or secrets are stored in Git.

## Directory layout

```text
.
├── Jenkinsfile
├── environments/
│   └── eastus/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── terraform.tfvars.example
├── modules/
│   └── README.md
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
3. Terraform initialization
4. Terraform validation
5. Terraform plan
6. Manual approval for deployments from `main`
7. Terraform apply using the reviewed plan
8. Workspace cleanup

GitHub Actions is intentionally not used for deployment or validation in this design.

See [docs/jenkins-cicd.md](docs/jenkins-cicd.md) for Jenkins setup and Azure credential requirements.

## Prerequisites

For local execution:

- Azure CLI
- Terraform >= 1.9
- Azure subscription with sufficient permissions

For Jenkins execution, the Jenkins agent also needs Git, Terraform, Azure CLI, and the required Jenkins credentials described in `docs/jenkins-cicd.md`.

## Local deployment

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

## Terraform state

The current foundation keeps backend configuration intentionally separate from the initial resource deployment. Before using this as a production landing zone, bootstrap a dedicated Azure Storage Account/blob container for Terraform remote state and configure the `azurerm` backend.

## Next phases

1. Bootstrap remote Terraform state in Azure Storage
2. Management groups and Azure Policy hierarchy
3. Hub-and-spoke networking and route tables
4. Private DNS and Private Endpoints
5. Identity/RBAC and Defender for Cloud
6. Workload spokes for application/data tiers
7. Azure Virtual WAN, VPN and ExpressRoute where required
8. Jenkins workload identity/federated authentication and stronger IaC security gates
