locals {
  # Cloud Build's default builder identity on Cloud Functions v2 / Firebase
  # Functions deploys. Constructed from the project number to avoid needing
  # compute.projects.get on the deployer SA (the data source equivalent would
  # require it).
  default_compute_sa_email = "${data.google_project.project.number}-compute@developer.gserviceaccount.com"

  operator_member = length(regexall("^serviceAccount:", var.terraform_operator_email)) > 0 ? var.terraform_operator_email : "user:${var.terraform_operator_email}"

  operator_roles = [
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/run.admin",
    "roles/secretmanager.admin",
  ]
}

resource "google_project_iam_member" "terraform_operator" {
  for_each = toset(local.operator_roles)

  project = var.project_id
  role    = each.value
  member  = local.operator_member
}

# ── Service Account — GitHub Actions Deployer ─────────────────────────────────

resource "google_service_account" "github_deployer" {
  account_id   = "${local.app_name}-deployer"
  display_name = "Finance Doctor GitHub Actions Deployer"
  description  = "Used by GitHub Actions in lopeztech/platform-infra to deploy Finance Doctor"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

locals {
  deployer_roles = [
    "roles/run.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/storage.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/logging.admin",
    "roles/monitoring.admin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/datastore.owner",
    "roles/appengine.appAdmin",
    "roles/firebase.admin",
    "roles/firebasehosting.admin",
    "roles/cloudfunctions.admin",
    "roles/firebaserules.admin",
  ]
}

resource "google_project_iam_member" "deployer" {
  for_each = toset(local.deployer_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

# ── Workload Identity Federation ──────────────────────────────────────────────

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

  attribute_condition = "assertion.repository == '${var.github_org}/${var.github_repo}' && assertion.ref == 'refs/heads/master'"
}

resource "google_service_account_iam_member" "github_wif_binding" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org}/${var.github_repo}"
}

# ── Workload Identity Federation — App Repo ──────────────────────────────────
# Allows the finance-doctor application repo to authenticate for deployments.

resource "google_iam_workload_identity_pool" "github_app" {
  workload_identity_pool_id = "${local.app_name}-app-github-pool"
  display_name              = "GitHub Actions Pool (App Repo)"
  description               = "Identity pool for finance-doctor app repo OIDC tokens"
  project                   = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github_app" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_app.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-app-provider"
  display_name                       = "GitHub OIDC Provider (App Repo)"
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

  attribute_condition = "assertion.repository == '${var.github_org}/${var.app_github_repo}' && assertion.ref == 'refs/heads/master'"
}

resource "google_service_account_iam_member" "github_app_wif_binding" {
  service_account_id = google_service_account.github_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_app.name}/attribute.repository/${var.github_org}/${var.app_github_repo}"
}

# ── Functions Deploy — Act-as bindings ────────────────────────────────────────
# firebase deploy --only functions needs two things beyond the deployer's
# project-level roles:
#   1. The deployer SA must be able to deploy a function that *runs as* the
#      finance-doctor-functions runtime SA (iam.serviceAccountUser, SA-scoped).
#   2. The Cloud Build default compute SA builds the function image and must
#      likewise be able to impersonate the runtime SA.

resource "google_service_account_iam_member" "deployer_act_as_functions_runtime" {
  service_account_id = google_service_account.functions_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_service_account_iam_member" "cloudbuild_act_as_functions_runtime" {
  service_account_id = google_service_account.functions_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.default_compute_sa_email}"
}
