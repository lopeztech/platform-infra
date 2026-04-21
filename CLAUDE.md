# platform-infra

Centralised Terraform IaC for all lopezcloud.dev GCP projects, managed via GitHub Actions.

## Repository layout

```
bootstrap/          # One-time per-environment setup (run manually, local state)
modules/            # Reusable Terraform modules (bigquery, cloudrun, firestore, gcs, iam, pubsub, secretmanager)
projects/
  _template/        # Scaffold for new projects
  home-plant-tracker/
  data-feeder/
.github/workflows/
  terraform-plan.yml   # Runs on PR — plans affected projects, comments results
  terraform-apply.yml  # Runs on push to master or workflow_dispatch — applies changes
versions.tf         # Root provider requirements (google ~> 5.0, terraform >= 1.6)
```

## Projects

| Project | Environments | GCP Project ID | Domain |
|---------|-------------|----------------|--------|
| home-plant-tracker | prod | home-plant-tracker-lcd | plants.lopezcloud.dev |
| data-feeder | single | data-feeder-lcd | datafeeder.lopezcloud.dev |
| finance-doctor | prod | finance-doctor-lcd | finance.lopezcloud.dev |
| fantasy-coach | prod | fantasy-coach-lcd | (TBD — see lopeztech/fantasy-coach#19) |

## Terraform workflow

```bash
# Bootstrap a new environment first (one-time, uses local state)
cd bootstrap
terraform init
terraform apply -var-file=terraform.tfvars

# Init a project (use GCS backend)
cd projects/<project>
terraform init \
  -backend-config="bucket=platform-infra-lcd-tf-state" \
  -backend-config="prefix=terraform/state/<project>/<env>"

# Plan / apply locally
terraform plan -var-file="environments/<env>/terraform.tfvars"
terraform apply -var-file="environments/<env>/terraform.tfvars"
```

## CI/CD

- **Plan**: runs on every PR touching `projects/**` or `modules/**`; posts plan output as PR comment
- **Apply**: runs on push to `master` (auto-detects changed projects); each project has its own workflow; `home-plant-tracker` and `data-feeder` require a GitHub `production` environment approval

### Required GitHub secrets

| Secret | Used by |
|--------|---------|
| `TF_STATE_BUCKET` | All projects |
| `BILLING_ACCOUNT_ID` | All projects (budget alerts) |
| `HOME_PLANT_TRACKER_WIF_PROVIDER` | home-plant-tracker |
| `HOME_PLANT_TRACKER_SA_EMAIL` | home-plant-tracker |
| `HOME_PLANT_TRACKER_FUNCTION_SOURCE_OBJECT` | home-plant-tracker |
| `GEMINI_API_KEY` | home-plant-tracker |
| `DATA_FEEDER_WIF_PROVIDER` | data-feeder |
| `DATA_FEEDER_SA_EMAIL` | data-feeder |
| `FANTASY_COACH_WIF_PROVIDER` | fantasy-coach |
| `FANTASY_COACH_SA_EMAIL` | fantasy-coach |

## Naming conventions

- Resources: lowercase with hyphens (`home-plant-tracker`, `data-feeder-api-prod`)
- GCS buckets: `{project_id}-{layer}-{env}` (e.g. `data-feeder-lcd-raw-prod`)
- Service accounts: `sa-{role}-{env}` (e.g. `sa-upload-api-prod`)
- All resources labelled with `env`, `managed = "terraform"`, and purpose-specific labels
- Region: `australia-southeast1`

## Adding a new project

1. Copy `projects/_template/` → `projects/<new-project>/`
2. Add change-detection filter in both workflow files
3. Add plan/apply jobs in both workflow files following existing patterns
4. Add required secrets to GitHub
5. Run bootstrap if a new GCP project is needed
