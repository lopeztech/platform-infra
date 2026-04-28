data "google_compute_default_service_account" "default" {
  project = var.project_id
}

# ── Terraform Operator IAM Roles ─────────────────────────────────────────────
# Grants the account running `terraform apply` the minimum roles needed to
# provision all resources in this configuration. The operator must already
# exist in GCP (e.g. a user account or a CI service account) — these bindings
# cannot bootstrap themselves from nothing, so run the initial apply as a
# project Owner, then these roles take over for subsequent runs.

locals {
  operator_member = length(regexall("^serviceAccount:", var.terraform_operator_email)) > 0 ? var.terraform_operator_email : "user:${var.terraform_operator_email}"

  operator_roles = [
    "roles/serviceusage.serviceUsageAdmin", # Enable / disable GCP APIs
    "roles/storage.admin",                  # Create and manage GCS buckets
    "roles/compute.admin",                  # Load balancer, CDN, SSL certs, forwarding rules
    "roles/iam.serviceAccountAdmin",        # Create and manage service accounts
    "roles/iam.workloadIdentityPoolAdmin",  # Create WIF pools and providers
    "roles/secretmanager.admin",            # Create and manage Secret Manager secrets
  ]
}

resource "google_project_iam_member" "terraform_operator" {
  for_each = toset(local.operator_roles)

  project = var.project_id
  role    = each.value
  member  = local.operator_member
}

# ── Service Account — GitHub Actions Deployer ────────────────────────────────
# Least-privilege account used to build and push Docker images, deploy to
# Cloud Run, and invalidate Cloud CDN cache after each deployment.

resource "google_service_account" "github_deployer" {
  account_id   = "${local.app_name}-deployer"
  display_name = "Plant Tracker GitHub Actions Deployer"
  description  = "Used by GitHub Actions in lopeztech/platform-infra to deploy the app"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# Full Terraform operator permissions — this SA runs terraform apply in CI/CD.
locals {
  deployer_roles = [
    "roles/run.admin",
    "roles/cloudfunctions.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/storage.admin",
    "roles/secretmanager.admin",
    "roles/compute.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/logging.admin",
    "roles/monitoring.admin",
    "roles/datastore.owner",
    "roles/resourcemanager.projectIamAdmin",
    "roles/apigateway.admin",
    "roles/serviceusage.apiKeysAdmin",
    "roles/cloudscheduler.admin",
    "roles/firebase.admin",
    "roles/firebasehosting.admin",
  ]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

# Act as Cloud Run service agent (required for deployments)
resource "google_service_account_iam_member" "deployer_act_as_run_sa" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_compute_default_service_account.default.email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
}

# ── Workload Identity Federation ──────────────────────────────────────────────
# Allows GitHub Actions in lopeztech/platform-infra to authenticate as the
# deployer service account without storing a long-lived JSON key.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${local.app_name}-github-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions OIDC tokens"
  project                   = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"
  project                            = var.project_id

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }

  # Only tokens from the platform-infra repository are accepted.
  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}' && assertion.ref == 'refs/heads/master'"
}

# Bind the WIF pool → service account impersonation (platform-infra Terraform CI)
resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

# ── WIF provider for home-plant-tracker app CI (function uploads) ─────────────
# Separate provider so the app repo can upload function ZIPs without needing
# access to the Terraform deployer credentials used by platform-infra.

resource "google_iam_workload_identity_pool_provider" "github_app" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-app-provider"
  display_name                       = "GitHub OIDC (app CI)"
  project                            = var.project_id

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${var.github_org}/home-plant-tracker' && assertion.ref == 'refs/heads/main'"
}

# Bind the app CI WIF → deployer service account
resource "google_service_account_iam_member" "github_app_wif_binding" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/home-plant-tracker"
}

# Allow the deployer SA to upload function ZIPs to the source bucket
resource "google_storage_bucket_iam_member" "deployer_function_source_writer" {
  bucket = google_storage_bucket.function_source.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_deployer.email}"
}

# ── Service Account — GitHub Actions Planner (PR read-only) ──────────────────
# Read-only SA used by `terraform plan` on PR branches. The deployer SA above
# is write-capable and locked to master; this SA is intentionally scoped to
# viewer-level so a rogue PR workflow cannot mutate GCP state.

resource "google_service_account" "github_planner" {
  account_id   = "${local.app_name}-planner"
  display_name = "Plant Tracker Terraform Planner (PR)"
  description  = "Read-only SA for terraform plan on PR branches"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

locals {
  planner_roles = [
    "roles/viewer",                          # Broad read for resource refresh
    "roles/iam.securityReviewer",            # Full IAM policy read (viewer misses some)
    "roles/secretmanager.secretAccessor",    # Drift detection on google_secret_manager_secret_version
    "roles/serviceusage.serviceUsageConsumer", # Required for `serviceusage.services.use` —
                                             # without it, plan refresh of Firebase project / Storage
                                             # buckets fails with USER_PROJECT_DENIED.
  ]
}

resource "google_project_iam_member" "planner" {
  for_each = toset(local.planner_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_planner.email}"
}

# ── WIF provider for PR-branch terraform plan ─────────────────────────────────
# Same pool as the deployer provider, but gated on event_name == 'pull_request'
# and bound to the read-only planner SA. The plan workflow uses this provider;
# the apply workflow continues to use github-provider (master-only + deployer).

resource "google_iam_workload_identity_pool_provider" "github_pr" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-pr-provider"
  display_name                       = "GitHub OIDC (PR plan)"
  project                            = var.project_id

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
    "attribute.ref"        = "assertion.ref"
    "attribute.event_name" = "assertion.event_name"
  }

  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}' && assertion.event_name == 'pull_request'"
}

# Only the planner SA can be impersonated from this provider's principal set;
# the deployer binding above uses the same principalSet but lives on a
# different provider, so event_name routing is what picks the SA.
resource "google_service_account_iam_member" "github_pr_wif_binding" {
  service_account_id = google_service_account.github_planner.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}
