# platform-infra

Centralised Terraform IaC for all [lopezcloud.dev](https://lopezcloud.dev) GCP projects, managed via GitHub Actions with Workload Identity Federation (no static keys).

## Repository layout

```
bootstrap/                          # One-time per-project setup (local state)
modules/
  bigquery/                         # Medallion-architecture BigQuery datasets
  budget/                           # Cloud Billing budget alerts
  cloudrun/                         # Cloud Run v2 service
  firestore/                        # Firestore native database
  gcs/                              # Medallion-layer GCS buckets (CMEK)
  iam/                              # Service accounts + WIF pool/providers
  monitoring/                       # Uptime checks + alert policies
  pubsub/                           # Pub/Sub topics + subscriptions
  secretmanager/                    # Secret Manager secrets
projects/
  _template/                        # Scaffold for new projects
  data-feeder/                      # Data ingestion pipeline
  finance-doctor/                   # Personal finance AI assistant
  home-plant-tracker/               # Smart plant care tracker
  sre-monitor/                      # SRE cost & reliability dashboard
.github/workflows/
  <project>-plan.yml                # PR plan + comment (per project)
  <project>-apply.yml               # Auto-apply on merge to master (per project)
versions.tf                         # Root provider requirements
```

## Projects

| Project | GCP Project ID | Domain | Environment | Key services |
|---------|---------------|--------|-------------|--------------|
| [home-plant-tracker](#home-plant-tracker) | `home-plant-tracker-lcd` | `plants.lopezcloud.dev` | prod | Firebase Hosting, Cloud Functions v2, API Gateway, Firestore, Gemini |
| [data-feeder](#data-feeder) | `data-feeder-lcd` | `datafeeder.lopezcloud.dev` | single | Cloud Run, BigQuery, Pub/Sub, GCS (medallion), CMEK |
| [sre-monitor](#sre-monitor) | `sre-monitor-lcd` | `sre.lopezcloud.dev` | prod | Cloud Run, Cloud CDN, BigQuery (billing export) |
| [finance-doctor](#finance-doctor) | `finance-doctor-lcd` | `finance.lopezcloud.dev` | prod | Cloud Run, Firestore, Gemini, OAuth |

### home-plant-tracker

Smart plant care app with AI-powered health analysis and watering recommendations.

**Architecture:**
- **Frontend**: Vite React SPA on Firebase Hosting (`plants.lopezcloud.dev`)
- **Backend**: Cloud Functions v2 (`plant-tracker-plants-api`) behind API Gateway
- **Database**: Firestore (native mode)
- **Storage**: GCS buckets for user images and ML training data
- **AI**: Gemini integration for plant analysis, diagnostics, and care recommendations
- **Scheduling**: Cloud Scheduler for weekly ML data exports
- **DNS**: Cloudflare (CNAME to Firebase Hosting + proxied CNAME for API)

**Key resources:**
- `google_firebase_hosting_site.plant_tracker` — static SPA hosting
- `google_cloudfunctions2_function.plants` — Node.js 20 CRUD + AI API
- `google_api_gateway_gateway.app` — OpenAPI 2.0 gateway with API key auth
- `google_firestore_database.app` — plant data (delete-protected)
- `google_storage_bucket.images` — user-uploaded photos (180-day lifecycle)
- `google_storage_bucket.ml_data` — Vertex AI training exports (90-day lifecycle)
- `google_cloud_scheduler_job.ml_export_weekly` — Sunday 3 AM AEST

### data-feeder

Data ingestion pipeline with medallion architecture (bronze/silver/gold).

**Architecture:**
- **API**: Cloud Run service behind HTTPS load balancer (`datafeeder.lopezcloud.dev`)
- **Pipeline**: Pub/Sub-driven (file-uploaded -> validation-complete -> pipeline-failed DLQ)
- **Storage**: 4 GCS buckets (raw/staging/curated/rejected) with CMEK encryption
- **Analytics**: BigQuery datasets (raw/staging/curated/audit) with pipeline job tracking
- **State**: Firestore for job status with composite indices
- **Encryption**: Cloud KMS with 5 keys, 90-day rotation

**Key resources:**
- `module.cloudrun` — data-feeder-api (scale 0-10, CPU idle billing)
- `module.gcs` — 4 medallion-layer buckets with lifecycle rules and CMEK
- `module.bigquery` — 4 datasets with partition pruning and audit tables
- `module.pubsub` — 3 topics, 4 subscriptions, dead-letter queue
- `module.firestore` — job tracking with PITR enabled
- `google_kms_crypto_key.layers` — 5 CMEK keys (bronze, silver, gold, firestore, bigquery)

### sre-monitor

SRE dashboard for GCP cost analysis and reliability monitoring.

**Architecture:**
- **Frontend**: React SPA served from GCS via Cloud CDN + HTTPS load balancer
- **Backend**: Cloud Run service (internal load balancer ingress)
- **Data**: BigQuery billing export dataset for cost queries
- **CDN**: Cloud CDN with configurable TTL (default 1h, max 24h)

**Key resources:**
- `google_cloud_run_v2_service.app` — API backend (scale 0-3)
- `google_storage_bucket.app` — static assets with versioning (3 versions retained)
- `google_compute_backend_service.app` — Cloud CDN enabled
- `google_bigquery_dataset.billing_export` — GCP billing data

### finance-doctor

AI-powered personal finance assistant.

**Architecture:**
- **App**: Cloud Run service with public ingress (no load balancer)
- **Database**: Firestore (native mode)
- **Auth**: Google OAuth 2.0 (client ID/secret in Secret Manager)
- **AI**: Gemini 2.5 Flash via Vertex AI

**Key resources:**
- `google_cloud_run_v2_service.app` — Next.js app (scale 0-3, CPU idle billing, startup boost)
- `google_firestore_database.default` — user data (delete-protected)
- `google_secret_manager_secret` — OAuth credentials + auth secret

## Modules

| Module | Purpose | Key inputs |
|--------|---------|------------|
| `bigquery` | Medallion-architecture datasets with audit tables | `project_id`, `region`, `kms_key_id` |
| `budget` | Cloud Billing budget alerts (email notifications) | `billing_account`, `monthly_budget_usd`, `notification_email` |
| `cloudrun` | Cloud Run v2 service with health probes + Secret Manager env | `service_account_email`, `secret_ids`, `gcs_bucket_names` |
| `firestore` | Firestore native DB with PITR + composite indices | `project_id`, `region` |
| `gcs` | Medallion-layer GCS buckets with CMEK, CORS, Pub/Sub notifications | `kms_key_ids`, `pubsub_topic_id`, `cors_origins` |
| `iam` | Service accounts + WIF pool/providers for GitHub Actions | `project_id`, `github_repos_allowed` |
| `monitoring` | Uptime checks (5min interval) + email alert policies | `services` (map of domain/path/display_name) |
| `pubsub` | Topics + subscriptions + dead-letter queue | `project_id`, `upload_sa_email` |
| `secretmanager` | Secret Manager secrets with SA access bindings | `project_id`, SA email inputs |

## Getting started

### Prerequisites

- Terraform >= 1.6
- Google Cloud SDK (`gcloud`)
- Access to the GCP projects listed above

### Bootstrap a new GCP project

```bash
cd bootstrap
terraform init
terraform apply -var-file=terraform.tfvars
```

This creates the GCS state bucket and enables required APIs. State is stored locally (chicken-and-egg).

### Work with an existing project

```bash
cd projects/<project>
terraform init \
  -backend-config="bucket=platform-infra-lcd-tf-state" \
  -backend-config="prefix=terraform/state/<project>/<env>"

terraform plan -var-file="environments/<env>/terraform.tfvars"
terraform apply -var-file="environments/<env>/terraform.tfvars"
```

### Add a new project

1. Copy `projects/_template/` to `projects/<new-project>/`
2. Create `<new-project>-plan.yml` and `<new-project>-apply.yml` in `.github/workflows/`
3. Add WIF provider + SA email secrets to GitHub
4. Run bootstrap if a new GCP project is needed
5. Push to master to trigger the first apply

## CI/CD

Each project has its own pair of GitHub Actions workflows:

| Workflow | Trigger | Action |
|----------|---------|--------|
| `<project>-plan.yml` | PR touching `projects/<project>/**` or `modules/**` | `terraform plan`, comments output on PR |
| `<project>-apply.yml` | Push to `master` (same paths) or `workflow_dispatch` | `terraform apply -auto-approve` + verification checks |

All apply workflows require GitHub **production** environment approval before running.

**Authentication**: Workload Identity Federation (OIDC) — no static service account keys. Each project has its own WIF provider scoped to `refs/heads/master`.

**Verification**: After each apply, project-specific infrastructure checks run (Cloud Run health, SSL cert coverage, API Gateway status, Firebase Hosting, etc.).

### Required GitHub secrets

| Secret | Used by | Purpose |
|--------|---------|---------|
| `TF_STATE_BUCKET` | All | GCS backend bucket |
| `BILLING_ACCOUNT_ID` | All | Budget alerts |
| `CLOUDFLARE_API_TOKEN` | All | DNS record management |
| `HOME_PLANT_TRACKER_WIF_PROVIDER` | home-plant-tracker | WIF provider resource name |
| `HOME_PLANT_TRACKER_SA_EMAIL` | home-plant-tracker | Deployer SA email |
| `HOME_PLANT_TRACKER_FUNCTION_SOURCE_OBJECT` | home-plant-tracker | Cloud Function ZIP name |
| `ML_ADMIN_TOKEN` | home-plant-tracker | ML endpoint auth token |
| `DATA_FEEDER_WIF_PROVIDER` | data-feeder | WIF provider resource name |
| `DATA_FEEDER_SA_EMAIL` | data-feeder | Deployer SA email |
| `SRE_MONITOR_WIF_PROVIDER` | sre-monitor | WIF provider resource name |
| `SRE_MONITOR_SA_EMAIL` | sre-monitor | Deployer SA email |
| `FINANCE_DOCTOR_WIF_PROVIDER` | finance-doctor | WIF provider resource name |
| `FINANCE_DOCTOR_SA_EMAIL` | finance-doctor | Deployer SA email |

## Naming conventions

| Resource type | Pattern | Example |
|--------------|---------|---------|
| GCP resources | lowercase with hyphens | `plant-tracker-plants-api` |
| GCS buckets | `{project_id}-{purpose}-{env}` | `data-feeder-lcd-raw-prod` |
| Service accounts | `{app}-{role}` | `plant-tracker-deployer` |
| KMS keys | `key-{layer}` | `key-bronze` |
| Labels | `app`, `environment`, `managed_by` | `managed_by = "terraform"` |

**Region**: `australia-southeast1` (Sydney) for all projects.

## State management

- **Backend**: GCS bucket `platform-infra-lcd-tf-state`
- **State path**: `terraform/state/<project>/<env>`
- **Locking**: GCS object versioning (built-in)
- **Bootstrap state**: Local only (not stored remotely)

## Budget alerts

Each project has configurable monthly budget alerts:

| Project | Monthly budget | Alert thresholds |
|---------|---------------|------------------|
| home-plant-tracker | $20 | 50%, 100%, forecasted 100% |
| data-feeder | $50 | 50%, 100%, forecasted 100% |
| sre-monitor | $20 | 50%, 100%, forecasted 100% |
| finance-doctor | $20 | 50%, 100%, forecasted 100% |
