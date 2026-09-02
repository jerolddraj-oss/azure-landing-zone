# Jenkins CI/CD for Azure Landing Zone

Jenkins is the CI/CD engine for this repository. GitHub is used for source control and pull-request collaboration; Jenkins performs Terraform validation, planning, approval, and deployment.

## Pipeline flow

```text
Git push / Pull Request
        |
        v
     GitHub
        |
     Webhook
        |
        v
     Jenkins
        |
        +--> terraform fmt
        +--> Azure authentication
        +--> Bootstrap remote state storage
        +--> terraform init (azurerm backend)
        +--> Adopt existing Azure resources if present
        +--> terraform validate
        +--> terraform plan
        |
        +--> Manual approval
        |
        +--> terraform apply
        |
        v
Azure Pay-As-You-Go Subscription
        |
        v
East US Landing Zone
```

## Jenkins agent prerequisites

Install these tools on the Jenkins Windows agent:

- Git
- Terraform 1.9 or later
- Azure CLI
- PowerShell

Keep Terraform and Azure CLI versions controlled on the Jenkins agent rather than downloading arbitrary versions during every build.

## Jenkins credentials

Create these Jenkins credentials. The credential IDs below are referenced by `Jenkinsfile` and should not be changed unless the pipeline is updated too.

| Jenkins credential ID | Type | Value |
|---|---|---|
| `azure-client-id` | Secret text | Azure application/client ID |
| `azure-client-secret` | Secret text | Azure application/client secret |
| `azure-tenant-id` | Secret text | Microsoft Entra tenant ID |
| `azure-subscription-id` | Secret text | Target Pay-As-You-Go subscription ID |

Do **not** place any of these values in GitHub, Terraform files, `terraform.tfvars`, or the Jenkinsfile.

### Azure permissions

The Jenkins service principal needs permission to create and manage the landing-zone resources. The current implementation intentionally does **not** create the subscription-level Reader role assignment by default because that operation requires `Microsoft.Authorization/roleAssignments/write`. Azure's Contributor role cannot assign Azure RBAC roles. If that RBAC assignment is required later, set `enable_platform_reader_assignment = true` only after granting the Jenkins identity an appropriate role such as Role Based Access Control Administrator or User Access Administrator. citeturn0search3turn0search5

## Remote Terraform state

The repository uses an `azurerm` backend in `environments/eastus/backend.tf`.

Jenkins automatically bootstraps a dedicated state resource group and Azure Storage Account if they do not already exist. The default state resource group is:

```text
jd-alz-tfstate-rg
```

The storage account name is derived from the first eight characters of the target subscription ID when the `TFSTATE_STORAGE_ACCOUNT` Jenkins parameter is left blank. Because Azure Storage account names are globally unique and must be 3-24 characters using lowercase letters and numbers, the parameter can be overridden if the derived name is already taken. citeturn2search0

The state is stored in the private `tfstate` container with the key `<name-prefix>-eastus.tfstate`.

The current bootstrap uses the storage account access key through the `ARM_ACCESS_KEY` environment variable because the existing Jenkins service principal does not have permission to create Azure RBAC assignments. This is a transitional implementation. The preferred production target is Microsoft Entra/OIDC workload identity plus Storage Blob Data Contributor access to the state container. HashiCorp recommends environment variables for sensitive backend credentials and recommends Entra-based authentication for new workloads. citeturn1search0turn1search2

Azure Blob Storage provides state locking for the `azurerm` backend, which prevents concurrent Terraform writers from using the same state. citeturn0search0turn0search2

## Existing-resource adoption

The previous Jenkins runs created Azure resources before the pipeline failed. Because the old pipeline used the default local backend, the state was lost when Jenkins cleaned the workspace. The new pipeline runs `scripts/adopt-existing.ps1` after remote backend initialization.

The script:

1. Checks whether each resource is already in Terraform state.
2. Checks whether the corresponding Azure resource exists.
3. Imports existing resources when required.
4. Leaves missing resources for normal Terraform creation.

This makes the pipeline safe to rerun against the resources that already exist instead of attempting to create duplicate resource groups.

## Create the Jenkins job

Recommended job type: **Multibranch Pipeline**.

1. Point the job at the GitHub repository.
2. Configure GitHub branch/PR discovery as required by your Jenkins installation.
3. Ensure the Jenkinsfile is loaded from the repository root.
4. Configure a GitHub webhook to trigger Jenkins after pushes and pull requests.
5. Run `PLAN` first and review the Terraform plan.
6. Run `APPLY` only after reviewing the plan and approving the Jenkins input step.
7. Protect the `main` branch with the repository's normal review controls.

## Jenkins parameters

- `ACTION`: `PLAN`, `APPLY`, or `DESTROY`.
- `NAME_PREFIX`: default `jd-alz`.
- `TFSTATE_STORAGE_ACCOUNT`: optional globally unique storage account name.

**Do not use `DESTROY` as a way to clean up the failed first deployment.** The new remote state/adoption flow is designed to safely bring the existing resources under Terraform management first.

## Deployment behavior

- `PLAN` validates and generates a Terraform plan without changing Azure resources.
- `APPLY` validates, adopts existing resources, generates a plan, waits for manual approval, and applies the approved plan.
- `DESTROY` generates a destroy plan and requires explicit manual approval before execution.
- The generated `tfplan` is deleted during post-build cleanup.
- Secrets are supplied only through Jenkins credentials.

## Known hardening work

1. Move Jenkins Azure authentication from client secret to Microsoft Entra workload identity federation/OIDC.
2. Replace the temporary state access-key method with Entra ID plus `Storage Blob Data Contributor` on the state container.
3. Commit the generated `.terraform.lock.hcl` after the first successful initialization.
4. Add TFLint and Checkov or an equivalent IaC security gate.
5. Add Azure Policy and management-group governance.
6. Add branch protection and required Jenkins status checks.
