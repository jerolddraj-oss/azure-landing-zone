# Azure CAF AI Agent implementation

## Current design

- Repository: `jerolddraj-oss/azure-landing-zone`
- Terraform root: `environments/eastus`
- Region: East US
- Network: existing hub VNet foundation
- CI/CD: GitHub Actions
- Azure authentication: Microsoft Entra workload identity federation (OIDC)
- Agent: Python CLI, optional OpenAI natural-language parsing

The agent writes a validated `terraform.tfvars.json` file matching the existing
Terraform root's variables. It does not generate arbitrary HCL, access Azure, or
apply changes. This separation makes the first release deterministic and safer.
The Terraform root is the authoritative source for resource definitions.

## Development flow

1. Update `agent/requirements.example.json` or supply a natural-language request.
2. Run `python agent/main.py --config <file> --dry-run` to inspect the result.
3. Generate a local `terraform.tfvars.json` only after reviewing the requirements.
4. Open a pull request; GitHub Actions checks Python syntax, Terraform formatting,
   initialization, validation, and Trivy configuration findings.
5. Merge the reviewed change to `main`; the workflow creates a Terraform plan.
6. A reviewer approves the protected `production` GitHub Environment before apply.
7. Verify Azure Activity Log and Terraform outputs.

## Scope limitations

This first iteration reuses the repository's existing single-subscription hub
foundation. Spoke VNets, ExpressRoute circuit/gateway provisioning, workload
migration for 150 VMware VMs, management-group hierarchy, Azure Policy
initiatives, and production-grade policy-as-code are follow-on modules. The
reserved GatewaySubnet does not itself create ExpressRoute connectivity.

## Operational notes

- Keep the Terraform state account and container pre-created.
- Use separate state keys and protected environments if adding dev/test/prod.
- Never run Jenkins and GitHub Actions applies concurrently against the same state.
- Do not store generated plan files or state in source control.
- Pin GitHub Actions to reviewed commit SHAs before adopting this workflow as a
  production supply-chain baseline; version tags are used here for readability.
- Review Azure Firewall and Bastion costs before the first apply.
