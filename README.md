# Azure CAF Landing Zone — Terraform + GitHub Actions

Enterprise-oriented Azure landing-zone foundation for a single Azure Pay-As-You-Go subscription, initially targeting East US.

## Current foundation

- Hub VNet with reserved Azure Firewall, Bastion, and Gateway subnets
- Azure Firewall Standard and Azure Bastion Standard
- Log Analytics workspace and Recovery Services vault
- Platform resource groups and a user-assigned managed identity
- Python requirements agent that generates validated Terraform variable JSON
- GitHub Actions validation, Trivy configuration scanning, OIDC-authenticated plan, and protected apply

> Cost warning: Azure Firewall Standard and Azure Bastion Standard are billable services. Review the Terraform plan and current Azure pricing before approving deployment.

## Repository layout

```text
.
├── .github/workflows/terraform-caf.yml
├── agent/
│   ├── main.py
│   ├── requirements.txt
│   ├── requirements.example.json
│   └── README.md
├── environments/eastus/
│   ├── backend.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── versions.tf
├── docs/
│   ├── architecture.md
│   ├── ai-agent-implementation.md
│   └── github-actions-oidc.md
└── Jenkinsfile
```

The Jenkinsfile is retained for reference during the transition. Do not run Jenkins and GitHub Actions apply jobs concurrently against the same Terraform state. GitHub Actions is the intended deployment path for this implementation.

## Python agent

Deterministic mode (no API key):

```bash
python agent/main.py --config agent/requirements.example.json --dry-run
```

Natural-language mode (optional OpenAI API):

```bash
python -m pip install -r agent/requirements.txt
export OPENAI_API_KEY="..."
python agent/main.py --request "Create an East US hub using CIDR 10.0.0.0/16 and prefix jd-alz" --dry-run
```

The agent validates inputs and generates `environments/eastus/terraform.tfvars.json`. The all-zero subscription ID in the example is a placeholder, not a deployable value. Generated variable files are ignored by Git. The agent never logs in to Azure or runs `terraform apply`.

## CI/CD setup

Follow [GitHub Actions OIDC setup](docs/github-actions-oidc.md) to:

1. Create a dedicated Azure Storage backend and container before Terraform initialization.
2. Configure a Microsoft Entra app/service principal and GitHub federated credentials.
3. Assign least-privilege Azure RBAC and Storage Blob Data Contributor on the state container.
4. Configure repository Actions variables.
5. Create a protected `production` environment with required reviewers and deployment branch restrictions.
6. Open a PR to run validation. Merge to `main` to create a plan and then request protected-environment approval before apply.

Required repository variables:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `TFSTATE_RESOURCE_GROUP`
- `TFSTATE_STORAGE_ACCOUNT`
- `TFSTATE_CONTAINER`

No client secret is required for GitHub Actions OIDC. Terraform state and plan artifacts can contain sensitive information; access must be restricted.

## CAF roadmap

The current repository is a single-subscription landing-zone foundation. Follow-on phases should add management-group hierarchy and policy initiatives, spoke VNets and peering, existing-firewall integration, ExpressRoute connectivity, workload-specific routes and NSGs, and onboarding/migration waves for the 150 on-premises VMware workloads. A reserved GatewaySubnet does not create ExpressRoute connectivity by itself.

See [architecture](docs/architecture.md) and [AI agent implementation](docs/ai-agent-implementation.md).
