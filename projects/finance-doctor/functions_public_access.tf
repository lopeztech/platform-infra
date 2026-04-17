# ── Public-access plumbing for Firebase Callable Cloud Functions ──────────────
# Firebase Callable Functions run as 2nd-gen Cloud Functions, which are
# Cloud Run services under the hood. The browser's OPTIONS preflight for
# every httpsCallable() invocation is unauthenticated at the transport
# layer — the Firebase ID token is carried inside the POST body, not as a
# Cloud Run IAM identity — so the underlying Cloud Run service needs an
# allUsers → run.invoker binding for preflights to get through.
#
# ── One-time manual bootstrap (per project) ───────────────────────────────────
# The organisation's iam.allowedPolicyMemberDomains constraint blocks
# allUsers bindings by default. We override the constraint at the project
# level. `roles/orgpolicy.policyAdmin` isn't grantable at the project
# level, and granting it at the org level would be excessive scope for the
# deployer SA — so the override itself is applied manually by a human
# admin once, using their own org-admin credentials:
#
#   cat > /tmp/allow-public.yaml <<'EOF'
#   name: projects/finance-doctor-lcd/policies/iam.allowedPolicyMemberDomains
#   spec:
#     rules:
#     - allowAll: true
#   EOF
#   gcloud org-policies set-policy /tmp/allow-public.yaml
#
# Once the constraint is lifted, Terraform manages the invoker bindings
# below. If the override is ever reverted at the org level, the next
# apply will surface it via a failed IAM binding.

locals {
  callable_functions = [
    "adviceChat",
    "dashboardTips",
    "taxAdvice",
    "investmentsAdvice",
    "expensesImport",
    "expensesMigrate",
    "expensesReanalyse",
  ]
}

# Cloud Functions v2 creates a Cloud Run service per function, but Cloud
# Run service names are constrained to [a-z0-9-] so Firebase lowercases
# the camelCase function name when provisioning the service (e.g.
# adviceChat → advicechat). We apply the same transform so the list
# above stays readable in code review. The services are created by
# `firebase deploy --only functions` from the finance-doctor app repo —
# this file adds IAM bindings on top of them.
resource "google_cloud_run_v2_service_iam_member" "public_callable_invoker" {
  for_each = toset([for fn in local.callable_functions : lower(fn)])

  project  = var.project_id
  location = var.region
  name     = each.value
  role     = "roles/run.invoker"
  member   = "allUsers"
}
