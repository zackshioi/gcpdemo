# Infra (Terraform)

All GCP infrastructure as code. Grows per feature alongside `app/`.

## Layout
| File | Contents |
|---|---|
| `versions.tf` | Terraform + google provider versions; provider config. |
| `variables.tf` | `project_id`, `region`, project-creation toggles. |
| `main.tf` | Optional project creation + API enablement. |
| `outputs.tf` | Project / region outputs. |
| `terraform.tfvars.example` | Copy to `terraform.tfvars` (gitignored) and fill in. |

## Usage
```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # then edit
terraform init
terraform plan
terraform apply
```
Auth uses Application Default Credentials: `gcloud auth application-default login`.

## Roadmap (added as features need them)
- F2: Firestore Native database.
- F3: Agent Engine instance (Memory Bank).
- F5: self-hosted Langfuse resources.
- F6: Artifact Registry repo, Cloud Run service, WIF pool/provider + deploy SA,
  and a GCS backend for remote state.
