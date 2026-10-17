# GitHub Actions + Azure OIDC

This guide replaces the repository's Jenkins deployment path with GitHub
Actions for the workflow added in `.github/workflows/terraform-caf.yml`.
The existing Jenkinsfile is retained for now; do not run both deployment
systems against the same state at the same time.

## 1. Bootstrap remote state separately

Create a dedicated resource group, Storage Account, and private blob container
for Terraform state before running the workflow. Use a globally unique storage
account name, enable secure transfer and blob versioning, and restrict network
access according to your organization's runner/network design. Keep state in a
dedicated account and do not commit state files.

Set the repository variables listed below after the state storage is created.
The workflow does not bootstrap the backend because Terraform cannot initialize
a backend that does not yet exist.

## 2. Create the Entra application / service principal

Create an app registration and service principal for GitHub Actions. Record its
Application (client) ID, Directory (tenant) ID, and target subscription ID.

Add a federated credential to the app registration:

- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`
- Subject for the production apply job:
  `repo:jerolddraj-oss/azure-landing-zone:environment:production`
- Subject for the main-branch plan job:
  `repo:jerolddraj-oss/azure-landing-zone:ref:refs/heads/main`

If using Azure CLI, substitute the real client ID and use the following shape
for the federated credential JSON:

```json
{
  "name": "github-actions-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:jerolddraj-oss/azure-landing-zone:environment:production",
  "description": "GitHub Actions production environment federation",
  "audiences": ["api://AzureADTokenExchange"]
}
```

Configure a separate federated credential for any additional GitHub environment
or branch subject used by your workflows. Do not create a client secret for OIDC.

## 3. Assign least-privilege permissions

Grant the deployment identity only the Azure roles required by the resources in
this repository, scoped to the intended subscription or resource groups. A
subscription-wide Contributor role is broad; prefer a custom role or narrower
scope after enumerating required resource-provider operations. Role assignments
and management-group / policy operations require additional permissions and
should be provisioned by a separately approved bootstrap identity.

For the remote state container, grant **Storage Blob Data Contributor** at the
container scope to the deployment identity. The workflow uses Entra data-plane
authentication, not storage account keys.

## 4. Configure GitHub repository variables

In **Settings → Secrets and variables → Actions → Variables**, create:

- `AZURE_CLIENT_ID`: app registration client ID
- `AZURE_TENANT_ID`: tenant ID
- `AZURE_SUBSCRIPTION_ID`: subscription ID
- `TFSTATE_RESOURCE_GROUP`: resource group containing state storage
- `TFSTATE_STORAGE_ACCOUNT`: globally unique storage account name
- `TFSTATE_CONTAINER`: existing private container, e.g. `tfstate`

These IDs are not secrets, but restrict who can edit repository variables and
workflow files. The workflow uses no client secret. Create a GitHub Environment
named `production`, configure required reviewers, and restrict deployment
branches to `main`.

## 5. Validate the OIDC subject and permissions

The production job requests an OIDC token only after approval of the protected
environment. The subject in the federated credential must match the actual
workflow environment exactly. Azure authentication and Azure authorization are
separate: a successful login does not imply the principal has sufficient RBAC.

## 6. First run

1. Open a pull request and confirm formatting, validation, Python tests and
   Trivy scanning pass.
2. Merge the reviewed change to `main`.
3. Confirm the plan job succeeds and inspect the uploaded plan summary.
4. Approve the `production` environment deployment only after reviewing the
   plan and estimated Azure costs.
5. Confirm the apply job result and inspect Azure Activity Log.

The landing zone currently provisions billable Azure Firewall Standard and
Bastion Standard resources. Do not approve the first apply until the region,
CIDRs, permissions, and cost estimate have been checked.
