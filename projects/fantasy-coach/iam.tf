# ── Terraform Operator IAM Roles ─────────────────────────────────────────────
# Grants the account that runs `terraform apply` the minimum roles it needs
# for this configuration. Bootstrap the first apply as a project Owner; after
# that, these bindings plus the deployer SA below are sufficient.

locals {
  operator_member = length(regexall("^serviceAccount:", var.terraform_operator_email)) > 0 ? var.terraform_operator_email : "user:${var.terraform_operator_email}"

  operator_roles = [
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/run.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/artifactregistry.admin",
  ]
}

resource "google_project_iam_member" "terraform_operator" {
  for_each = toset(local.operator_roles)

  project = var.project_id
  role    = each.value
  member  = local.operator_member
}

# ── Runtime SA — used by the Cloud Run revision at request time ──────────────
# Least privilege on purpose. Firestore / Secret Manager / Vertex roles are
# added in the issues that introduce those dependencies (#15, #16, #22).

resource "google_service_account" "runtime" {
  account_id   = "${local.app_name}-runtime"
  display_name = "Fantasy Coach Cloud Run runtime"
  description  = "Identity the Cloud Run revision runs as"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

# The Cloud Run service + the precompute Job (fantasy-coach#65) both run as
# this SA. They share the Firestore state (matches Repository + prediction
# cache) so both need read/write. roles/datastore.user covers both.
locals {
  runtime_roles = [
    "roles/datastore.user", # Firestore read + write — matches + prediction cache
    # Future issues add:
    #   - roles/secretmanager.secretAccessor (#16 Secret Manager)
    #   - roles/aiplatform.user           (#22 Vertex Gemini)
  ]
}

resource "google_project_iam_member" "runtime" {
  for_each = toset(local.runtime_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# ── Deployer SA — used by GitHub Actions to roll revisions ───────────────────

resource "google_service_account" "github_deployer" {
  account_id   = "${local.app_name}-deployer"
  display_name = "Fantasy Coach GitHub Actions Deployer"
  description  = "Builds images and rolls Cloud Run revisions from CI"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

locals {
  deployer_roles = [
    "roles/run.admin",
    "roles/artifactregistry.writer",
    "roles/iam.serviceAccountUser",        # to let Cloud Run run as runtime SA
    "roles/iam.serviceAccountAdmin",       # terraform manages this SA
    "roles/iam.workloadIdentityPoolAdmin", # terraform manages the WIF pool
    "roles/storage.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/logging.admin",
    "roles/monitoring.admin",
    # Firebase Hosting deploys from lopeztech/fantasy-coach#72.
    "roles/firebasehosting.admin",
    # Create google_firebase_project + google_firebase_web_app during apply.
    # Without this the first apply fails with "caller does not have permission"
    # on both resources. Granted before the apply runs — chicken-and-egg.
    "roles/firebase.admin",
    # Manage google_identity_platform_config (authorised domains, Google SSO).
    # firebase.admin does not imply identitytoolkit write access.
    "roles/identityplatform.admin",
    # Create + version the Firebase Web App config secrets (firebase_secrets.tf).
    # Needs .admin rather than .accessor because terraform manages the secret
    # resources themselves, not just reads their latest version.
    "roles/secretmanager.admin",
  ]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

# Deployer must be able to deploy a Cloud Run revision whose identity is the
# runtime SA. That's a per-SA binding (iam.serviceAccountUser), not project-
# wide, so scope it explicitly.
resource "google_service_account_iam_member" "deployer_act_as_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
}

# ── Workload Identity Federation ─────────────────────────────────────────────
# Two pools: one for terraform runs from platform-infra, one for app-repo
# deploys from lopeztech/fantasy-coach. Kept separate so a compromised app
# repo can't push terraform changes, and vice versa.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${local.app_name}-github-pool"
  display_name              = "GHA Pool (platform-infra)"
  description               = "Identity pool for platform-infra OIDC tokens"
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

  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}' && assertion.ref == 'refs/heads/master'"
}

resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

# App-repo pool — lets lopeztech/fantasy-coach CI build + deploy images.

resource "google_iam_workload_identity_pool" "github_app" {
  workload_identity_pool_id = "${local.app_name}-app-github-pool"
  display_name              = "GHA Pool (app repo)"
  description               = "Identity pool for lopeztech/fantasy-coach OIDC tokens"
  project                   = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github_app" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_app.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-app-provider"
  display_name                       = "GitHub OIDC Provider (app repo)"
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

  # App-repo deploys run from main, not master.
  attribute_condition = "assertion.repository == '${var.github_org}/${var.app_github_repo}' && assertion.ref == 'refs/heads/main'"
}

resource "google_service_account_iam_member" "github_app_wif_binding" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_app.name}/attribute.repository/${var.github_org}/${var.app_github_repo}"
}

# ── Scheduler-invoker SA (fantasy-coach#65) ──────────────────────────────────
# Dedicated identity Cloud Scheduler uses to invoke the precompute Job. Kept
# separate from runtime/deployer so a compromise in Scheduler can only run
# the Job, not touch anything else. The binding that grants run.invoker on
# the Job itself lives in scheduler.tf to avoid a resource-ordering loop.

resource "google_service_account" "scheduler" {
  account_id   = "${local.app_name}-scheduler"
  display_name = "Fantasy Coach Cloud Scheduler invoker"
  description  = "Identity Cloud Scheduler uses to trigger the precompute Job"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}
