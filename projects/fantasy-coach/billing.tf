# ── Budget Alerts ─────────────────────────────────────────────────────────────
# Scale-to-zero + Firestore free tier keep today's costs near $0, but we want
# a wired-up early-warning path for the moment GCP credits run out. The
# ``modules/budget`` module (already in use by data-feeder) creates a single
# project-wide budget with email notifications at 50/80/100 % spend plus
# forecasted-100 %, satisfying the "simple alarm first, per-SKU dashboards
# later" approach agreed in fantasy-coach#63.
#
# A Looker Studio dashboard + BigQuery billing export is an explicit
# follow-up. Billing Export → BigQuery has to be enabled at the billing
# account level (needs ``roles/billing.admin`` on the billing account, which
# is outside this project's Terraform scope), so it's documented as a manual
# step in docs/cost.md in the paired lopeztech/fantasy-coach PR rather than
# attempted here.

module "budget" {
  source = "../../modules/budget"

  project_id         = var.project_id
  billing_account    = var.billing_account
  monthly_budget_usd = var.monthly_budget_usd
  notification_email = var.notification_email

  depends_on = [google_project_service.apis]
}
