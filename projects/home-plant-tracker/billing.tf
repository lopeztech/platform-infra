# ── Stripe billing secrets + price IDs ───────────────────────────────────────
# Activation checklist (do once Stripe account is set up):
#
#   1. Create Stripe Products + Prices in the Stripe Dashboard:
#        - Home Pro — Monthly + Annual
#        - Landscaper Pro — Monthly + Annual
#      Copy each Price ID (price_...) into the corresponding variable below
#      via *.tfvars — do NOT commit price IDs to source.
#
#   2. Create a Stripe webhook endpoint pointing at
#        https://${var.domain}/billing/webhook
#      with events:
#        - checkout.session.completed
#        - customer.subscription.created
#        - customer.subscription.updated
#        - customer.subscription.deleted
#        - invoice.payment_succeeded
#        - invoice.payment_failed
#      Copy the signing secret (whsec_...).
#
#   3. Populate the two Secret Manager entries below with the real values:
#        gcloud secrets versions add ${local.app_name}-stripe-secret-key   --data-file=-
#        gcloud secrets versions add ${local.app_name}-stripe-webhook-secret --data-file=-
#
#   4. Flip `var.billing_enabled = true` and re-run apply.
#
# Until step 4, the function ships with BILLING_ENABLED=false and every tier
# check + quota no-ops. This lets the code land safely without any customer impact.

resource "google_secret_manager_secret" "stripe_secret_key" {
  secret_id = "${local.app_name}-stripe-secret-key"
  project   = var.project_id
  replication {
    auto {}
  }
  labels    = local.labels
  depends_on = [google_project_service.apis]
}

# Placeholder version so the Cloud Function can bind secret_environment_variables
# on the very first apply. The backend skips Stripe entirely when
# BILLING_ENABLED != "true", so this placeholder is never used. Overwrite it
# with a real Stripe secret key via:
#   gcloud secrets versions add home-plant-tracker-stripe-secret-key --data-file=-
resource "google_secret_manager_secret_version" "stripe_secret_key_placeholder" {
  secret      = google_secret_manager_secret.stripe_secret_key.id
  secret_data = "DISABLED"
  lifecycle { ignore_changes = [secret_data] }
}

resource "google_secret_manager_secret" "stripe_webhook_secret" {
  secret_id = "${local.app_name}-stripe-webhook-secret"
  project   = var.project_id
  replication {
    auto {}
  }
  labels    = local.labels
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "stripe_webhook_secret_placeholder" {
  secret      = google_secret_manager_secret.stripe_webhook_secret.id
  secret_data = "DISABLED"
  lifecycle { ignore_changes = [secret_data] }
}

# IAM — allow the function SA to read the Stripe secrets at runtime.

resource "google_secret_manager_secret_iam_member" "plants_function_stripe_secret_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.stripe_secret_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.plants_function.email}"
}

resource "google_secret_manager_secret_iam_member" "plants_function_stripe_webhook_secret" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.stripe_webhook_secret.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.plants_function.email}"
}
