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
        +--> terraform init
        +--> terraform validate
        +--> terraform plan
        |
        +--> Manual approval on main
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

Install these tools on the Jenkins agent:

- Git
- Terraform 1.9 or later
- Azure CLI
- A Linux shell capable of running the pipeline `sh` steps

Keep Terraform and Azure CLI versions controlled on the Jenkins agent rather than downloading arbitrary versions during every build.

## Jenkins credentials

Create these Jenkins credentials. The credential IDs below are referenced by `Jenkinsfile` and should not be changed unless the pipeline is updated too.

| Jenkins credential ID | Type | Value |
|---|---|---|
| `azure-service-principal` | Username with password | Azure application/client ID as username; client secret as password |
| `azure-tenant-id` | Secret text | Microsoft Entra tenant ID |
| `azure-subscription-id` | Secret text | Target Pay-As-You-Go subscription ID |

Do **not** place any of these values in GitHub, Terraform files, `terraform.tfvars`, or the Jenkinsfile.

### Azure permissions

The service principal must have sufficient permissions at the target subscription scope to create and manage the resources defined by the landing zone. For a production implementation, use least privilege and review the exact Terraform resource set before granting broader permissions.

## Create the Jenkins job

Recommended job type: **Multibranch Pipeline**.

1. Point the job at the GitHub repository.
2. Configure GitHub branch/PR discovery as required by your Jenkins installation.
3. Ensure the Jenkinsfile is loaded from the repository root.
4. Configure a GitHub webhook to trigger Jenkins after pushes and pull requests.
5. Run a non-production branch first to verify `fmt`, `init`, `validate`, and `plan`.
6. Protect the `main` branch with the repository's normal review controls.

## Deployment behavior

- Pull requests and non-main branches run validation and Terraform plan.
- `main` runs the same validation and plan, then pauses for a manual approval.
- Only after approval does Jenkins execute `terraform apply`.
- The generated `tfplan` is used for the approved apply and is deleted during post-build cleanup.
- Secrets are supplied only through Jenkins credentials.

## Terraform state

For a production landing zone, Terraform state should be stored remotely in an Azure Storage Account rather than in the Jenkins workspace.

The next infrastructure-hardening step should be to bootstrap a dedicated Azure Storage Account and blob container for Terraform state, enable appropriate storage security controls, and configure an `azurerm` backend. The backend bootstrap must be completed before switching the deployment environment to remote state.

## Recommended next hardening steps

1. Bootstrap remote Terraform state in Azure Storage.
2. Use Microsoft Entra workload identity/federated authentication for Jenkins where supported, avoiding long-lived client secrets.
3. Add TFLint and Checkov or an equivalent IaC security gate.
4. Add Azure Policy and management-group governance.
5. Add branch protection and required Jenkins status checks.
6. Separate plan and apply permissions if organizational controls require it.
