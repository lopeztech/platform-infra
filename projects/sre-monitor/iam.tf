data "google_compute_default_service_account" "default" {
  project = var.project_id
}

locals {
  operator_member = length(regexall("^serviceAccount:", var.terraform_operator_email)) > 0 ? var.terraform_operator_email : "user:${var.terraform_operator_email}"

  operator_roles = [
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.admin",
    "roles/compute.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/run.admin",
    "roles/artifactregistry.admin",
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
  display_name = "SRE Monitor GitHub Actions Deployer"
  description  = "Used by GitHub Actions in lopeztech/platform-infra to deploy SRE Monitor"
  project      = var.project_id

  depends_on = [google_project_service.apis]
}

resource "google_storage_bucket_iam_member" "deployer_object_admin" {
  bucket = google_storage_bucket.app.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_project_iam_member" "deployer_cdn_invalidator" {
  project = var.project_id
  role    = "roles/compute.networkAdmin"
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_project_iam_member" "deployer_run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.github_deployer.email}"
}

resource "google_service_account_iam_member" "deployer_act_as_run_sa" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${data.google_compute_default_service_account.default.email}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.github_deployer.email}"
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
