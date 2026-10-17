# CAF Landing Zone Requirements Agent

This agent translates a structured JSON file—or an optional natural-language
request using the OpenAI API—into validated Terraform variable JSON for the
existing `environments/eastus` root.

## Safety model

- The agent only generates configuration; it does not log in to Azure.
- It does not execute Terraform or make deployment decisions.
- Inputs are checked locally for required fields, UUID format, allowed name
  prefix characters, valid non-overlapping IPv4 CIDRs, and tag types.
- Generated configuration must be reviewed. Run `terraform plan` and review
  the plan before deployment.
- Never put credentials or secrets in prompts or config files.

## Deterministic mode (no AI API key)

From the repository root:

```bash
python agent/main.py --config agent/requirements.example.json --dry-run
python agent/main.py --config agent/requirements.example.json --output environments/eastus/terraform.tfvars.json
```

Replace the example subscription ID with your real subscription ID before
using the generated configuration for deployment. The all-zero UUID is a
placeholder and is not deployable.

## Natural-language mode

Install the optional dependency and set `OPENAI_API_KEY` in your local shell
(or use an approved secret manager):

```bash
python -m pip install -r agent/requirements.txt
export OPENAI_API_KEY="..."
python agent/main.py --request "Create the East US CAF hub foundation using hub CIDR 10.100.0.0/20 and prefix jd-alz" --dry-run
```

PowerShell equivalent:

```powershell
python -m pip install -r agent/requirements.txt
$env:OPENAI_API_KEY = Read-Host "OpenAI API key"
python agent/main.py --request "Create the East US CAF hub foundation using hub CIDR 10.100.0.0/20 and prefix jd-alz" --dry-run
```

The agent's current Terraform contract is intentionally limited to the variables
supported by the existing East US root. Add new schema fields and corresponding
Terraform variables together in a reviewed pull request.
